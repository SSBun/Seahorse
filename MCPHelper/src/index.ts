#!/usr/bin/env node
import http from "node:http";
import { randomUUID } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { isInitializeRequest } from "@modelcontextprotocol/sdk/types.js";
import { BridgeClient } from "./bridgeClient.js";
import { registerTools } from "./tools.js";

const mcpToken = requireEnv("SEAHORSE_MCP_TOKEN");
const bridgeToken = requireEnv("SEAHORSE_BRIDGE_TOKEN");
const bridgeURL = process.env.SEAHORSE_BRIDGE_URL ?? "http://127.0.0.1:17374";
const port = Number(process.env.SEAHORSE_MCP_PORT ?? "17373");
const host = "127.0.0.1";

const bridge = new BridgeClient(bridgeURL, bridgeToken);
const transports = new Map<string, StreamableHTTPServerTransport>();

function createServer(): McpServer {
  const server = new McpServer({
    name: "seahorse",
    version: "0.1.0",
  });
  registerTools(server, bridge);
  return server;
}

const httpServer = http.createServer(async (req, res) => {
  if (req.url !== "/mcp") {
    sendJSON(res, 404, { error: "Not found" });
    return;
  }

  if (req.headers.authorization !== `Bearer ${mcpToken}`) {
    sendJSON(res, 401, { error: "Unauthorized" });
    return;
  }

  try {
    if (req.method === "POST") {
      await handlePost(req, res);
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
  } catch (error) {
    sendJSON(res, 500, { error: error instanceof Error ? error.message : "Internal server error" });
  }
});

httpServer.listen(port, host, () => {
  console.error(`Seahorse MCP helper listening on http://${host}:${port}/mcp`);
});

async function handlePost(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
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

  const server = createServer();
  await server.connect(transport);
  await transport.handleRequest(req, res, body);
}

async function readJSON(req: http.IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  if (chunks.length === 0) {
    return undefined;
  }
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

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}
