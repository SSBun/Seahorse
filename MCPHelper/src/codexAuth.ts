import { chmod, mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import type { OAuthCredential } from "@earendil-works/pi-ai";
import { openaiCodexProvider } from "@earendil-works/pi-ai/providers/openai-codex";

export type CodexAuthStatus =
  | { status: "disconnected" }
  | { status: "connecting" }
  | { status: "connected" }
  | { status: "failed"; error: string };

export type CodexLogin = (onAuthorizationURL: (url: string) => void) => Promise<OAuthCredential>;
export type CodexRefresh = (credential: OAuthCredential) => Promise<OAuthCredential>;

/** Owns Codex OAuth login and keeps its refresh token in a user-only local file. */
export class CodexAuth {
  private state: CodexAuthStatus = { status: "disconnected" };
  private loginTask?: Promise<void>;
  private authorizationURLTask?: Promise<string>;
  private mutation = Promise.resolve();

  constructor(
    private readonly credentialPath: string,
    private readonly login: CodexLogin = loginCodex,
    private readonly refresh: CodexRefresh = refreshCodex,
    private readonly now: () => number = Date.now,
  ) {}

  async status(): Promise<CodexAuthStatus> {
    if (this.state.status === "connecting") return this.state;
    if (await this.readCredentials()) {
      this.state = { status: "connected" };
    } else if (this.state.status !== "failed") {
      this.state = { status: "disconnected" };
    }
    return this.state;
  }

  async startLogin(): Promise<{ authorizationURL: string }> {
    if (this.authorizationURLTask) {
      return { authorizationURL: await this.authorizationURLTask };
    }

    this.state = { status: "connecting" };
    let resolveURL!: (url: string) => void;
    let rejectURL!: (error: Error) => void;
    let didProvideURL = false;
    const authorizationURLTask = new Promise<string>((resolve, reject) => {
      resolveURL = resolve;
      rejectURL = reject;
    });
    this.authorizationURLTask = authorizationURLTask;

    this.loginTask = this.login(
      (url) => {
        didProvideURL = true;
        resolveURL(url);
      },
    )
      .then(async (credentials) => {
        await this.writeCredentials(credentials);
        this.state = { status: "connected" };
      })
      .catch(() => {
        const error = new Error("Codex sign-in failed. Please try again.");
        this.state = { status: "failed", error: error.message };
        if (!didProvideURL) rejectURL(error);
      })
      .finally(() => {
        this.loginTask = undefined;
        if (this.authorizationURLTask === authorizationURLTask) {
          this.authorizationURLTask = undefined;
        }
      });
    void this.loginTask;

    return { authorizationURL: await authorizationURLTask };
  }

  async disconnect(): Promise<void> {
    await this.serialize(async () => {
      await rm(this.credentialPath, { force: true });
    });
    this.state = { status: "disconnected" };
  }

  async getAccessToken(): Promise<string> {
    return this.serialize(async () => {
      let credentials = await this.readCredentials();
      if (!credentials) {
        throw new Error("Codex is not connected. Open Settings > AI to connect it.");
      }

      if (credentials.expires <= this.now() + 60_000) {
        try {
          credentials = await this.refresh(credentials);
          await this.writeCredentials(credentials);
        } catch {
          throw new Error("Codex authorization expired. Reconnect it in Settings > AI.");
        }
      }
      return credentials.access;
    });
  }

  private async readCredentials(): Promise<OAuthCredential | undefined> {
    try {
      const value = JSON.parse(await readFile(this.credentialPath, "utf8")) as Partial<OAuthCredential>;
      if (
        value.type !== "oauth" ||
        typeof value.access !== "string" ||
        typeof value.refresh !== "string" ||
        typeof value.expires !== "number"
      ) {
        return undefined;
      }
      return value as OAuthCredential;
    } catch {
      return undefined;
    }
  }

  private async writeCredentials(credentials: OAuthCredential): Promise<void> {
    const directory = dirname(this.credentialPath);
    const temporaryPath = `${this.credentialPath}.tmp`;
    await mkdir(directory, { recursive: true, mode: 0o700 });
    await writeFile(temporaryPath, JSON.stringify(credentials), { encoding: "utf8", mode: 0o600 });
    await rename(temporaryPath, this.credentialPath);
    await chmod(this.credentialPath, 0o600);
  }

  private async serialize<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.mutation.then(operation, operation);
    this.mutation = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
  }
}

const codexOAuth = openaiCodexProvider().auth.oauth!;

async function loginCodex(onAuthorizationURL: (url: string) => void): Promise<OAuthCredential> {
  return codexOAuth.login({
    prompt: async (prompt) => {
      if (prompt.type === "select") return "browser";
      if (prompt.type === "manual_code") {
        return new Promise<string>((_resolve, reject) => {
          const abort = () => reject(new Error("Browser sign-in finished"));
          if (prompt.signal?.aborted) {
            abort();
          } else {
            prompt.signal?.addEventListener("abort", abort, { once: true });
          }
        });
      }
      throw new Error("Codex browser sign-in requires no manual input");
    },
    notify: (event) => {
      if (event.type === "auth_url") onAuthorizationURL(event.url);
    },
  });
}

async function refreshCodex(credential: OAuthCredential): Promise<OAuthCredential> {
  return codexOAuth.refresh(credential);
}

export interface CodexAuthLike {
  status(): Promise<CodexAuthStatus>;
  startLogin(): Promise<{ authorizationURL: string }>;
  disconnect(): Promise<void>;
  getAccessToken(): Promise<string>;
}
