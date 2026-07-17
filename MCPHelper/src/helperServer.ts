import { randomUUID } from "node:crypto";
import http from "node:http";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
import { getBuiltinModels } from "@earendil-works/pi-ai/providers/all";
import type { AgentPromptRequest, AgentPromptResponse } from "./agentRuntime.js";
import type { BridgeClient } from "./bridgeClient.js";
import type { CodexAuthLike } from "./codexAuth.js";
import type { CodexImageGeneratorLike } from "./codexImage.js";
import { registerTools } from "./tools.js";

export interface AgentRuntimeLike {
  prompt(request: AgentPromptRequest): Promise<AgentPromptResponse>;
}

interface HelperServerOptions {
  mcpEnabled: boolean;
  mcpToken: string;
  internalToken: string;
  bridge: BridgeClient;
  agentRuntime: AgentRuntimeLike;
  codexAuth: CodexAuthLike;
  codexImageGenerator: CodexImageGeneratorLike;
}

/** Creates the local HTTP server shared by the internal Agent and external MCP routes. */
export function createHelperServer(options: HelperServerOptions): http.Server {
  const transports = new Map<string, StreamableHTTPServerTransport>();

  function createMCPServer(): McpServer {
    const server = new McpServer({ name: "seahorse", version: "0.1.0" });
    registerTools(server, options.bridge);
    return server;
  }

  async function handleMCPPost(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    const body = await readJSON(req);
    const existingSessionId = req.headers["mcp-session-id"];

    if (typeof existingSessionId === "string") {
      const transport = transports.get(existingSessionId);
      if (!transport) {
        sendJSON(res, 404, { error: "Unknown session" });
        return;
      }
      await transport.handleRequest(req, res, body);
      return;
    }

    if (!isInitializeRequest(body)) {
      sendJSON(res, 400, { error: "Missing session. Initialize first." });
      return;
    }

    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (sessionId) => {
        transports.set(sessionId, transport);
      },
    });
    transport.onclose = () => {
      if (transport.sessionId) {
        transports.delete(transport.sessionId);
      }
    };

    const server = createMCPServer();
    await server.connect(transport);
    await transport.handleRequest(req, res, body);
  }

  async function handleAgent(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    if (req.headers.authorization !== `Bearer ${options.internalToken}`) {
      sendJSON(res, 401, { error: "Unauthorized" });
      return;
    }
    if (req.method !== "POST") {
      sendJSON(res, 405, { error: "Method not allowed" });
      return;
    }

    const body = await readJSON(req);
    if (!isAgentPromptRequest(body)) {
      sendJSON(res, 400, { error: "Invalid agent request" });
      return;
    }
    const response = await options.agentRuntime.prompt(body);
    sendJSON(res, 200, response);
  }

  async function handleCodexAuth(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    if (req.headers.authorization !== `Bearer ${options.internalToken}`) {
      sendJSON(res, 401, { error: "Unauthorized" });
      return;
    }

    if (req.method === "GET") {
      sendJSON(res, 200, await options.codexAuth.status());
      return;
    }
    if (req.method === "POST") {
      sendJSON(res, 200, await options.codexAuth.startLogin());
      return;
    }
    if (req.method === "DELETE") {
      await options.codexAuth.disconnect();
      sendJSON(res, 200, { status: "disconnected" });
      return;
    }
    sendJSON(res, 405, { error: "Method not allowed" });
  }

  async function handleCodexModels(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    if (req.headers.authorization !== `Bearer ${options.internalToken}`) {
      sendJSON(res, 401, { error: "Unauthorized" });
      return;
    }
    if (req.method !== "GET") {
      sendJSON(res, 405, { error: "Method not allowed" });
      return;
    }
    sendJSON(
      res,
      200,
      getBuiltinModels("openai-codex").map((model) => ({
        id: model.id,
        name: model.name,
        supportsImageGeneration: model.input.includes("image"),
      })),
    );
  }

  async function handleCodexImage(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    if (req.headers.authorization !== `Bearer ${options.internalToken}`) {
      sendJSON(res, 401, { error: "Unauthorized" });
      return;
    }
    if (req.method !== "POST") {
      sendJSON(res, 405, { error: "Method not allowed" });
      return;
    }
    const body = await readJSON(req);
    if (!isCodexImageRequest(body)) {
      sendJSON(res, 400, { error: "Invalid Codex image request" });
      return;
    }
    sendJSON(
      res,
      200,
      await options.codexImageGenerator.generate(
        body.model,
        body.prompt,
        body.referenceImageBase64,
      ),
    );
  }

  async function handleMCP(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    if (!options.mcpEnabled) {
      sendJSON(res, 404, { error: "Not found" });
      return;
    }
    if (req.headers.authorization !== `Bearer ${options.mcpToken}`) {
      sendJSON(res, 401, { error: "Unauthorized" });
      return;
    }

    if (req.method === "POST") {
      await handleMCPPost(req, res);
      return;
    }
    if (req.method === "GET" || req.method === "DELETE") {
      const sessionId = req.headers["mcp-session-id"];
      if (typeof sessionId !== "string") {
        sendJSON(res, 400, { error: "Missing mcp-session-id" });
        return;
      }
      const transport = transports.get(sessionId);
      if (!transport) {
        sendJSON(res, 404, { error: "Unknown session" });
        return;
      }
      await transport.handleRequest(req, res);
      return;
    }
    sendJSON(res, 405, { error: "Method not allowed" });
  }

  return http.createServer(async (req, res) => {
    try {
      if (req.url === "/agent") {
        await handleAgent(req, res);
        return;
      }
      if (req.url === "/agent/auth/codex") {
        await handleCodexAuth(req, res);
        return;
      }
      if (req.url === "/agent/providers/codex/models") {
        await handleCodexModels(req, res);
        return;
      }
      if (req.url === "/agent/images/codex") {
        await handleCodexImage(req, res);
        return;
      }
      if (req.url === "/mcp") {
        await handleMCP(req, res);
        return;
      }
      sendJSON(res, 404, { error: "Not found" });
    } catch (error) {
      const status = error instanceof SyntaxError ? 400 : 500;
      sendJSON(res, status, {
        error: error instanceof Error ? error.message : "Internal server error",
      });
    }
  });
}

function isCodexImageRequest(value: unknown): value is {
  model: string;
  prompt: string;
  referenceImageBase64?: string;
} {
  if (!value || typeof value !== "object") return false;
  const request = value as {
    model?: unknown;
    prompt?: unknown;
    referenceImageBase64?: unknown;
  };
  return (
    typeof request.model === "string" &&
    request.model.length > 0 &&
    typeof request.prompt === "string" &&
    request.prompt.trim().length > 0 &&
    (request.referenceImageBase64 === undefined ||
      (typeof request.referenceImageBase64 === "string" &&
        request.referenceImageBase64.length > 0))
  );
}

function isAgentPromptRequest(value: unknown): value is AgentPromptRequest {
  if (!value || typeof value !== "object") return false;
  const request = value as Partial<AgentPromptRequest>;
  const configuration = request.configuration;
  return (
    typeof request.sessionId === "string" &&
    request.sessionId.length > 0 &&
    typeof request.message === "string" &&
    request.message.trim().length > 0 &&
    !!configuration &&
    typeof configuration.model === "string" &&
    configuration.model.length > 0 &&
    (configuration.provider === "openai-codex" ||
      ((configuration.provider === "openai-compatible" ||
        configuration.provider === "claude-compatible") &&
        typeof configuration.apiToken === "string" &&
        configuration.apiToken.length > 0 &&
        typeof configuration.apiBaseURL === "string" &&
        configuration.apiBaseURL.length > 0))
  );
}

async function readJSON(req: http.IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  if (chunks.length === 0) return undefined;
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function sendJSON(res: http.ServerResponse, status: number, body: unknown): void {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(data),
  });
  res.end(data);
}
