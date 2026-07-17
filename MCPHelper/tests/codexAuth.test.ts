import { mkdtemp, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CodexAuth, type CodexLogin } from "../src/codexAuth.js";

const directories: string[] = [];

afterEach(async () => {
  const { rm } = await import("node:fs/promises");
  await Promise.all(directories.splice(0).map((directory) => rm(directory, { recursive: true })));
});

describe("CodexAuth", () => {
  it("returns the browser URL and stores completed OAuth credentials with user-only permissions", async () => {
    const credentialPath = await temporaryCredentialPath();
    let finishLogin!: () => void;
    const login = vi.fn<CodexLogin>(async (onAuthorizationURL) => {
      onAuthorizationURL("https://auth.openai.com/authorize");
      await new Promise<void>((resolve) => {
        finishLogin = resolve;
      });
      return credentials("access-token", Date.now() + 3_600_000);
    });
    const auth = new CodexAuth(credentialPath, login);

    await expect(auth.startLogin()).resolves.toEqual({
      authorizationURL: "https://auth.openai.com/authorize",
    });
    await expect(auth.status()).resolves.toEqual({ status: "connecting" });

    finishLogin();
    await waitForStatus(auth, "connected");
    const stored = JSON.parse(await readFile(credentialPath, "utf8")) as Record<string, unknown>;
    expect(stored).toMatchObject({ access: "access-token", refresh: "refresh-token" });
    expect((await stat(credentialPath)).mode & 0o777).toBe(0o600);
  });

  it("refreshes an expiring token and persists the replacement", async () => {
    const credentialPath = await temporaryCredentialPath();
    const login = vi.fn<CodexLogin>(async (onAuthorizationURL) => {
      onAuthorizationURL("https://auth.openai.com/authorize");
      return credentials("expired-token", 1_000);
    });
    const refresh = vi.fn(async () => credentials("fresh-token", 100_000));
    const auth = new CodexAuth(credentialPath, login, refresh, () => 10_000);
    await auth.startLogin();
    await waitForStatus(auth, "connected");

    await expect(auth.getAccessToken()).resolves.toBe("fresh-token");
    expect(refresh).toHaveBeenCalledWith(expect.objectContaining({ refresh: "refresh-token" }));
    await expect(readFile(credentialPath, "utf8")).resolves.toContain("fresh-token");
  });

  it("deletes credentials when disconnected", async () => {
    const credentialPath = await temporaryCredentialPath();
    const login = vi.fn<CodexLogin>(async (onAuthorizationURL) => {
      onAuthorizationURL("https://auth.openai.com/authorize");
      return credentials("access-token", Date.now() + 3_600_000);
    });
    const auth = new CodexAuth(credentialPath, login);
    await auth.startLogin();
    await waitForStatus(auth, "connected");

    await auth.disconnect();

    await expect(auth.status()).resolves.toEqual({ status: "disconnected" });
    await expect(auth.getAccessToken()).rejects.toThrow("Codex is not connected");
  });

  it("does not expose provider errors when sign-in fails", async () => {
    const credentialPath = await temporaryCredentialPath();
    const login = vi.fn<CodexLogin>(async () => {
      throw new Error("upstream response with sensitive details");
    });
    const auth = new CodexAuth(credentialPath, login);

    await expect(auth.startLogin()).rejects.toThrow("Codex sign-in failed. Please try again.");
    await expect(auth.status()).resolves.toEqual({
      status: "failed",
      error: "Codex sign-in failed. Please try again.",
    });
  });
});

function credentials(access: string, expires: number) {
  return { type: "oauth" as const, access, refresh: "refresh-token", expires, accountId: "account-id" };
}

async function temporaryCredentialPath(): Promise<string> {
  const directory = await mkdtemp(join(tmpdir(), "seahorse-codex-auth-"));
  directories.push(directory);
  return join(directory, "nested", "auth.json");
}

async function waitForStatus(auth: CodexAuth, expected: string): Promise<void> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if ((await auth.status()).status === expected) return;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  throw new Error(`Timed out waiting for ${expected}`);
}
