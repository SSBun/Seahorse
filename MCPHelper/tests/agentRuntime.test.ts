import http from "node:http";
import type { AddressInfo } from "node:net";
import { Agent } from "@earendil-works/pi-agent-core";
import {
  fauxAssistantMessage,
  fauxToolCall,
  registerFauxProvider,
} from "@earendil-works/pi-ai/compat";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { BridgeClient } from "../src/bridgeClient.js";
import {
  AgentRuntime,
  createPiAgent,
  createReadOnlyAgentTools,
  type AgentConfiguration,
  type AgentFactory,
} from "../src/agentRuntime.js";

const registrations: Array<{ unregister: () => void }> = [];

afterEach(() => {
  for (const registration of registrations.splice(0)) {
    registration.unregister();
  }
});

describe("AgentRuntime", () => {
  it("uses an OpenAI-compatible endpoint for the production Pi tool loop", async () => {
    const requests: Array<Record<string, unknown>> = [];
    const apiServer = http.createServer(async (request, response) => {
      const chunks: Buffer[] = [];
      for await (const chunk of request) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      }
      requests.push(JSON.parse(Buffer.concat(chunks).toString("utf8")) as Record<string, unknown>);
      const callNumber = requests.length;
      const choice =
        callNumber === 1
          ? {
              index: 0,
              delta: {
                role: "assistant",
                tool_calls: [
                  {
                    index: 0,
                    id: "search-1",
                    type: "function",
                    function: {
                      name: "search_bookmarks",
                      arguments: '{"query":"swift","limit":5}',
                    },
                  },
                ],
              },
              finish_reason: "tool_calls",
            }
          : {
              index: 0,
              delta: { role: "assistant", content: "Found the Swift bookmark." },
              finish_reason: "stop",
            };
      response.writeHead(200, { "content-type": "text/event-stream" });
      response.end(
        `data: ${JSON.stringify({
          id: `chatcmpl-${callNumber}`,
          object: "chat.completion.chunk",
          created: 1,
          model: "test-model",
          choices: [choice],
        })}\n\ndata: [DONE]\n\n`,
      );
    });
    await new Promise<void>((resolve) => apiServer.listen(0, "127.0.0.1", resolve));
    const { port } = apiServer.address() as AddressInfo;
    const call = vi.fn(async () => [
      { id: "00000000-0000-4000-8000-000000000001", title: "Swift" },
    ]);

    try {
      const runtime = new AgentRuntime({ call } as unknown as BridgeClient);
      const result = await runtime.prompt({
        sessionId: "production-session",
        message: "Find Swift bookmarks",
        configuration: {
          provider: "openai-compatible",
          apiToken: "api-token",
          apiBaseURL: `http://127.0.0.1:${port}/v1`,
          model: "test-model",
        },
      });

      expect(result).toEqual({
        answer: "Found the Swift bookmark.",
        bookmarkIds: ["00000000-0000-4000-8000-000000000001"],
      });
      expect(requests).toHaveLength(2);
      expect(requests[0]).toMatchObject({ model: "test-model", stream: true });
      expect(requests[0].tools).toBeInstanceOf(Array);
      expect(requests[1].messages).toEqual(
        expect.arrayContaining([expect.objectContaining({ role: "tool" })]),
      );
    } finally {
      await new Promise<void>((resolve, reject) => {
        apiServer.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });

  it("uses a Claude-compatible Anthropic Messages endpoint", async () => {
    const requests: Array<{ path: string | undefined; apiKey: string | undefined; body: unknown }> = [];
    const apiServer = http.createServer(async (request, response) => {
      const chunks: Buffer[] = [];
      for await (const chunk of request) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      }
      requests.push({
        path: request.url,
        apiKey: request.headers["x-api-key"] as string | undefined,
        body: JSON.parse(Buffer.concat(chunks).toString("utf8")) as unknown,
      });
      const events = [
        {
          type: "message_start",
          message: {
            id: "msg-1",
            type: "message",
            role: "assistant",
            model: "claude-model",
            content: [],
            stop_reason: null,
            stop_sequence: null,
            usage: { input_tokens: 5, output_tokens: 1 },
          },
        },
        {
          type: "content_block_start",
          index: 0,
          content_block: { type: "text", text: "" },
        },
        {
          type: "content_block_delta",
          index: 0,
          delta: { type: "text_delta", text: "Claude answer." },
        },
        { type: "content_block_stop", index: 0 },
        {
          type: "message_delta",
          delta: { stop_reason: "end_turn", stop_sequence: null },
          usage: { output_tokens: 3 },
        },
        { type: "message_stop" },
      ];
      response.writeHead(200, { "content-type": "text/event-stream" });
      response.end(events.map((event) => `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`).join(""));
    });
    await new Promise<void>((resolve) => apiServer.listen(0, "127.0.0.1", resolve));
    const { port } = apiServer.address() as AddressInfo;

    try {
      const runtime = new AgentRuntime({ call: vi.fn() } as unknown as BridgeClient);
      const result = await runtime.prompt({
        sessionId: "claude-production-session",
        message: "Hello",
        configuration: {
          provider: "claude-compatible",
          apiToken: "claude-token",
          apiBaseURL: `http://127.0.0.1:${port}`,
          model: "claude-model",
        },
      });

      expect(result).toEqual({ answer: "Claude answer.", bookmarkIds: [] });
      expect(requests).toHaveLength(1);
      expect(requests[0]).toMatchObject({ path: "/v1/messages", apiKey: "claude-token" });
      expect(requests[0].body).toMatchObject({ model: "claude-model", stream: true });
    } finally {
      await new Promise<void>((resolve, reject) => {
        apiServer.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });

  it("executes bridge tools and keeps conversation state by session id", async () => {
    const faux = registerFauxProvider();
    registrations.push(faux);
    faux.setResponses([
      fauxAssistantMessage(
        fauxToolCall("search_bookmarks", { query: "swift", limit: 5 }, { id: "search-1" }),
        { stopReason: "toolUse" },
      ),
      fauxAssistantMessage("I found two Swift bookmarks."),
      (context) => {
        const remembersFirstTurn = context.messages.some(
          (message) =>
            message.role === "user" &&
            Array.isArray(message.content) &&
            message.content.some((block) => block.type === "text" && block.text.includes("Find Swift")),
        );
        return fauxAssistantMessage(remembersFirstTurn ? "The first result was retained." : "Context was lost.");
      },
    ]);

    const call = vi.fn(async () => [
      { id: "00000000-0000-4000-8000-000000000001", title: "Swift" },
      { id: "00000000-0000-4000-8000-000000000002", title: "SwiftUI" },
    ]);
    const createAgent: AgentFactory = (_configuration, tools, sessionId) =>
      new Agent({
        sessionId,
        initialState: {
          systemPrompt: "Test agent",
          model: faux.getModel(),
          thinkingLevel: "off",
          tools,
        },
      });
    const runtime = new AgentRuntime({ call } as unknown as BridgeClient, createAgent);
    const configuration: AgentConfiguration = {
      provider: "openai-compatible",
      apiToken: "test-token",
      apiBaseURL: "https://example.com/v1",
      model: "test-model",
    };

    const first = await runtime.prompt({
      sessionId: "session-1",
      message: "Find Swift bookmarks",
      configuration,
    });
    const second = await runtime.prompt({
      sessionId: "session-1",
      message: "What was the first result?",
      configuration,
    });

    expect(first).toEqual({
      answer: "I found two Swift bookmarks.",
      bookmarkIds: [
        "00000000-0000-4000-8000-000000000001",
        "00000000-0000-4000-8000-000000000002",
      ],
    });
    expect(second.answer).toBe("The first result was retained.");
    expect(call).toHaveBeenCalledWith("search_bookmarks", { query: "swift", limit: 5 });
  });

  it("exposes only read-only bookmark metadata tools", () => {
    const tools = createReadOnlyAgentTools({ call: vi.fn() } as unknown as BridgeClient);

    expect(tools.map((tool) => tool.name)).toEqual([
      "search_bookmarks",
      "get_bookmark",
      "get_bookmarks",
      "list_tags",
      "search_tags",
      "list_categories",
      "search_categories",
    ]);
  });

  it("creates a Codex agent backed by the connected OAuth token", async () => {
    const getAccessToken = vi.fn(async () => "codex-access-token");
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-session",
      {
        getAccessToken,
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );

    expect(agent.state.model).toMatchObject({
      provider: "openai-codex",
      id: "gpt-5.4-mini",
      api: "openai-codex-responses",
    });
    await expect(agent.getApiKey?.("openai-codex")).resolves.toBe("codex-access-token");
  });

  it("creates a Claude-compatible agent backed by an Anthropic Messages endpoint", async () => {
    const agent = createPiAgent(
      {
        provider: "claude-compatible",
        apiToken: "claude-token",
        apiBaseURL: "https://claude.example.com/",
        model: "claude-model",
      },
      [],
      "claude-session",
    );

    expect(agent.state.model).toMatchObject({
      provider: "seahorse-claude-compatible",
      id: "claude-model",
      api: "anthropic-messages",
      baseUrl: "https://claude.example.com",
    });
    expect(await agent.getApiKey?.("seahorse-claude-compatible")).toBe("claude-token");
  });
});
