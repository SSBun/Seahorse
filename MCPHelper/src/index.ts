#!/usr/bin/env node
import { AgentRuntime } from "./agentRuntime.js";
import { BridgeClient } from "./bridgeClient.js";
import { CodexAuth } from "./codexAuth.js";
import { CodexImageGenerator } from "./codexImage.js";
import { createHelperServer } from "./helperServer.js";

const mcpToken = requireEnv("SEAHORSE_MCP_TOKEN");
const internalToken = requireEnv("SEAHORSE_BRIDGE_TOKEN");
const bridgeURL = process.env.SEAHORSE_BRIDGE_URL ?? "http://127.0.0.1:17374";
const port = Number(process.env.SEAHORSE_MCP_PORT ?? "17373");
const host = "127.0.0.1";
const mcpEnabled = process.env.SEAHORSE_MCP_ENABLED === "true";
const codexAuthPath = requireEnv("SEAHORSE_CODEX_AUTH_PATH");

const bridge = new BridgeClient(bridgeURL, internalToken);
const codexAuth = new CodexAuth(codexAuthPath);
const codexImageGenerator = new CodexImageGenerator(codexAuth);
const agentRuntime = new AgentRuntime(bridge, undefined, codexAuth);
const httpServer = createHelperServer({
  mcpEnabled,
  mcpToken,
  internalToken,
  bridge,
  agentRuntime,
  codexAuth,
  codexImageGenerator,
});

httpServer.listen(port, host, () => {
  const mcpStatus = mcpEnabled ? "enabled" : "disabled";
  console.error(`Seahorse helper listening on http://${host}:${port} (Agent enabled, MCP ${mcpStatus})`);
});

const parentProcessID = process.ppid;
const parentWatchdog = setInterval(() => {
  if (parentProcessID > 1 && process.ppid !== parentProcessID) {
    process.exit(0);
  }
}, 1000);
parentWatchdog.unref();

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}
