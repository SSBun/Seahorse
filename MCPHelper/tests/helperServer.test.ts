import type { AddressInfo } from "node:net";
import { LATEST_PROTOCOL_VERSION } from "@modelcontextprotocol/sdk/types.js";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { BridgeClient } from "../src/bridgeClient.js";
import type { CodexAuthLike } from "../src/codexAuth.js";
import type { CodexImageGeneratorLike } from "../src/codexImage.js";
import { createHelperServer } from "../src/helperServer.js";

const servers: Array<ReturnType<typeof createHelperServer>> = [];

afterEach(async () => {
  await Promise.all(
    servers.splice(0).map(
      (server) =>
        new Promise<void>((resolve, reject) => {
          server.close((error) => (error ? reject(error) : resolve()));
        }),
    ),
  );
});

describe("helper server", () => {
  it("preserves authenticated MCP initialization when MCP is enabled", async () => {
    const server = createHelperServer({
      mcpEnabled: true,
      mcpToken: "external-token",
      internalToken: "internal-token",
      bridge: { call: vi.fn() } as unknown as BridgeClient,
      agentRuntime: { prompt: vi.fn() },
      codexAuth: codexAuth(),
      codexImageGenerator: codexImageGenerator(),
    });
    servers.push(server);
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;

    const response = await fetch(`http://127.0.0.1:${port}/mcp`, {
      method: "POST",
      headers: {
        authorization: "Bearer external-token",
        accept: "application/json, text/event-stream",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: LATEST_PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: { name: "test-client", version: "1.0.0" },
        },
      }),
    });

    expect(response.status).toBe(200);
    expect(response.headers.get("mcp-session-id")).toBeTruthy();
    await expect(response.text()).resolves.toContain('"serverInfo"');
  });

  it("authenticates the internal agent endpoint while MCP is disabled", async () => {
    const prompt = vi.fn(async () => ({ answer: "Found it.", bookmarkIds: ["bookmark-1"] }));
    const server = createHelperServer({
      mcpEnabled: false,
      mcpToken: "external-token",
      internalToken: "internal-token",
      bridge: { call: vi.fn() } as unknown as BridgeClient,
      agentRuntime: { prompt },
      codexAuth: codexAuth(),
      codexImageGenerator: codexImageGenerator(),
    });
    servers.push(server);
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;
    const body = {
      sessionId: "session-1",
      message: "Find Swift bookmarks",
      configuration: {
        provider: "openai-compatible",
        apiToken: "api-token",
        apiBaseURL: "https://example.com/v1",
        model: "test-model",
      },
    };

    const unauthorized = await fetch(`http://127.0.0.1:${port}/agent`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    const authorized = await fetch(`http://127.0.0.1:${port}/agent`, {
      method: "POST",
      headers: {
        authorization: "Bearer internal-token",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });
    const disabledMCP = await fetch(`http://127.0.0.1:${port}/mcp`, {
      method: "POST",
      headers: {
        authorization: "Bearer external-token",
        "content-type": "application/json",
      },
      body: "{}",
    });

    expect(unauthorized.status).toBe(401);
    expect(authorized.status).toBe(200);
    await expect(authorized.json()).resolves.toEqual({ answer: "Found it.", bookmarkIds: ["bookmark-1"] });
    expect(prompt).toHaveBeenCalledWith(body);
    expect(disabledMCP.status).toBe(404);
  });

  it("accepts a Codex Agent request without API key fields", async () => {
    const prompt = vi.fn(async () => ({ answer: "Codex works.", bookmarkIds: [] }));
    const server = createHelperServer({
      mcpEnabled: false,
      mcpToken: "external-token",
      internalToken: "internal-token",
      bridge: { call: vi.fn() } as unknown as BridgeClient,
      agentRuntime: { prompt },
      codexAuth: codexAuth(),
      codexImageGenerator: codexImageGenerator(),
    });
    servers.push(server);
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;
    const body = {
      sessionId: "codex-session",
      message: "Find bookmarks",
      configuration: {
        provider: "openai-codex",
        model: "gpt-5.4-mini",
      },
    };

    const response = await fetch(`http://127.0.0.1:${port}/agent`, {
      method: "POST",
      headers: {
        authorization: "Bearer internal-token",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });

    expect(response.status).toBe(200);
    expect(prompt).toHaveBeenCalledWith(body);
  });

  it("accepts a Claude-compatible Agent request", async () => {
    const prompt = vi.fn(async () => ({ answer: "Claude works.", bookmarkIds: [] }));
    const server = createHelperServer({
      mcpEnabled: false,
      mcpToken: "external-token",
      internalToken: "internal-token",
      bridge: { call: vi.fn() } as unknown as BridgeClient,
      agentRuntime: { prompt },
      codexAuth: codexAuth(),
      codexImageGenerator: codexImageGenerator(),
    });
    servers.push(server);
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;
    const body = {
      sessionId: "claude-session",
      message: "Find bookmarks",
      configuration: {
        provider: "claude-compatible",
        apiToken: "claude-token",
        apiBaseURL: "https://claude.example.com",
        model: "claude-model",
      },
    };

    const response = await fetch(`http://127.0.0.1:${port}/agent`, {
      method: "POST",
      headers: {
        authorization: "Bearer internal-token",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });

    expect(response.status).toBe(200);
    expect(prompt).toHaveBeenCalledWith(body);
  });

  it("starts, reports, and disconnects Codex OAuth behind internal authentication", async () => {
    const auth = codexAuth();
    const server = createHelperServer({
      mcpEnabled: false,
      mcpToken: "external-token",
      internalToken: "internal-token",
      bridge: { call: vi.fn() } as unknown as BridgeClient,
      agentRuntime: { prompt: vi.fn() },
      codexAuth: auth,
      codexImageGenerator: codexImageGenerator(),
    });
    servers.push(server);
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;
    const endpoint = `http://127.0.0.1:${port}/agent/auth/codex`;

    const unauthorized = await fetch(endpoint);
    const started = await fetch(endpoint, {
      method: "POST",
      headers: { authorization: "Bearer internal-token" },
    });
    const status = await fetch(endpoint, {
      headers: { authorization: "Bearer internal-token" },
    });
    const disconnected = await fetch(endpoint, {
      method: "DELETE",
      headers: { authorization: "Bearer internal-token" },
    });

    expect(unauthorized.status).toBe(401);
    await expect(started.json()).resolves.toEqual({
      authorizationURL: "https://auth.openai.com/authorize",
    });
    await expect(status.json()).resolves.toEqual({ status: "connected" });
    await expect(disconnected.json()).resolves.toEqual({ status: "disconnected" });
    expect(auth.startLogin).toHaveBeenCalledOnce();
    expect(auth.disconnect).toHaveBeenCalledOnce();
  });

  it("lists Codex models and generates images behind internal authentication", async () => {
    const imageGenerator = codexImageGenerator();
    const server = createHelperServer({
      mcpEnabled: false,
      mcpToken: "external-token",
      internalToken: "internal-token",
      bridge: { call: vi.fn() } as unknown as BridgeClient,
      agentRuntime: { prompt: vi.fn() },
      codexAuth: codexAuth(),
      codexImageGenerator: imageGenerator,
    });
    servers.push(server);
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;
    const headers = { authorization: "Bearer internal-token" };

    const models = await fetch(`http://127.0.0.1:${port}/agent/providers/codex/models`, { headers });
    const unauthorized = await fetch(`http://127.0.0.1:${port}/agent/images/codex`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ model: "gpt-5.4", prompt: "A seahorse" }),
    });
    const image = await fetch(`http://127.0.0.1:${port}/agent/images/codex`, {
      method: "POST",
      headers: { ...headers, "content-type": "application/json" },
      body: JSON.stringify({
        model: "gpt-5.4",
        prompt: "A seahorse",
        referenceImageBase64: "cmVmZXJlbmNl",
      }),
    });

    expect(models.status).toBe(200);
    expect(await models.json()).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: "gpt-5.4", supportsImageGeneration: true }),
      ]),
    );
    expect(unauthorized.status).toBe(401);
    await expect(image.json()).resolves.toEqual({ imageBase64: "aW1hZ2U=" });
    expect(imageGenerator.generate).toHaveBeenCalledWith(
      "gpt-5.4",
      "A seahorse",
      "cmVmZXJlbmNl",
    );
  });
});

function codexAuth(): CodexAuthLike {
  return {
    status: vi.fn(async () => ({ status: "connected" as const })),
    startLogin: vi.fn(async () => ({ authorizationURL: "https://auth.openai.com/authorize" })),
    disconnect: vi.fn(async () => undefined),
    getAccessToken: vi.fn(async () => "access-token"),
  };
}

function codexImageGenerator(): CodexImageGeneratorLike {
  return {
    generate: vi.fn(async () => ({ imageBase64: "aW1hZ2U=" })),
  };
}
