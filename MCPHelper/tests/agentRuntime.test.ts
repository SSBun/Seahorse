import http from "node:http";
import type { AddressInfo } from "node:net";
import { Agent } from "@earendil-works/pi-agent-core";
import {
  createAssistantMessageEventStream,
  fauxAssistantMessage,
  fauxToolCall,
  registerApiProvider,
  registerFauxProvider,
  unregisterApiProviders,
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

  it.each(["Codex error: HTTP 500 upstream", "Codex error: rate limit 429"])(
    "retries one transient streamed Codex error without exposing the failed attempt: %s",
    async (errorMessage) => {
      const faux = registerFauxProvider();
      registrations.push(faux);
      faux.setResponses([
        fauxAssistantMessage("Discarded partial response.", {
          stopReason: "error",
          errorMessage,
        }),
        fauxAssistantMessage("Retried response."),
      ]);
      const agent = createPiAgent(
        { provider: "openai-codex", model: "gpt-5.4-mini" },
        [],
        "codex-retry-session",
        {
          getAccessToken: vi.fn(async () => "codex-access-token"),
          status: vi.fn(),
          startLogin: vi.fn(),
          disconnect: vi.fn(),
        },
      );

      const stream = agent.streamFn(
        faux.getModel(),
        { systemPrompt: "Test", messages: [] },
        { apiKey: "test-token" },
      );
      const eventTypes: string[] = [];
      const events = (async () => {
        for await (const event of stream) {
          eventTypes.push(event.type);
        }
      })();

      const response = await stream.result();
      await events;

      expect(faux.state.callCount).toBe(2);
      expect(eventTypes).not.toContain("error");
      expect(eventTypes.at(-1)).toBe("done");
      expect(response.content).toEqual([{ type: "text", text: "Retried response." }]);
    },
  );

  it("stops after one transient Codex retry", async () => {
    const faux = registerFauxProvider();
    registrations.push(faux);
    faux.setResponses([
      fauxAssistantMessage([], {
        stopReason: "error",
        errorMessage: "Codex error: HTTP 500 upstream",
      }),
      fauxAssistantMessage([], {
        stopReason: "error",
        errorMessage: "Codex error: HTTP 503 upstream",
      }),
      fauxAssistantMessage("Unexpected third attempt."),
    ]);
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-single-retry-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );

    const stream = agent.streamFn(
      faux.getModel(),
      { systemPrompt: "Test", messages: [] },
      { apiKey: "test-token" },
    );

    const response = await stream.result();

    expect(faux.state.callCount).toBe(2);
    expect(faux.getPendingResponseCount()).toBe(1);
    expect(response.stopReason).toBe("error");
    expect(response.errorMessage).toContain("503");
  });

  it.each([
    {
      status: 400,
      code: "bad_request",
      message: "bad request",
      expectedRequestCount: 1,
      expectedError: "bad request",
    },
    {
      status: 401,
      code: "unauthorized",
      message: "internal server error",
      expectedRequestCount: 1,
      expectedError: "internal server error",
    },
    {
      status: 429,
      code: "rate_limit_exceeded",
      message: "temporary rate limit",
      expectedRequestCount: 2,
      expectedError: "usage limit",
    },
    {
      status: 429,
      code: "insufficient_quota",
      message: "insufficient_quota",
      expectedRequestCount: 1,
      expectedError: "usage limit",
    },
    {
      status: 500,
      code: "server_error",
      message: "temporary failure",
      expectedRequestCount: 2,
      expectedError: "temporary failure",
    },
    {
      status: 501,
      code: "unknown_error",
      message: "plain failure",
      expectedRequestCount: 2,
      expectedError: "plain failure",
    },
  ])("applies the Codex HTTP retry policy to $status", async ({
    status,
    code,
    message,
    expectedRequestCount,
    expectedError,
  }) => {
    let requestCount = 0;
    const apiServer = http.createServer((_request, response) => {
      requestCount += 1;
      response.writeHead(status, {
        "content-type": "application/json",
        "retry-after-ms": "0",
      });
      response.end(JSON.stringify({ error: { code, message } }));
    });
    await new Promise<void>((resolve) => apiServer.listen(0, "127.0.0.1", resolve));
    const { port } = apiServer.address() as AddressInfo;
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-non-retryable-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );
    const authPayload = Buffer.from(
      JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "test" } }),
    ).toString("base64url");

    try {
      const response = await agent.streamFn(
        { ...agent.state.model, baseUrl: `http://127.0.0.1:${port}` },
        { systemPrompt: "Test", messages: [] },
        { apiKey: `e30.${authPayload}.x`, transport: "sse" },
      ).result();

      expect(requestCount).toBe(expectedRequestCount);
      expect(response.stopReason).toBe("error");
      expect(response.errorMessage).toContain(expectedError);
    } finally {
      await new Promise<void>((resolve, reject) => {
        apiServer.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });

  it("shares one retry budget when a 500 retry ends in a network failure", async () => {
    let requestCount = 0;
    const apiServer = http.createServer((_request, response) => {
      requestCount += 1;
      if (requestCount === 1) {
        response.writeHead(500, {
          "content-type": "application/json",
          "retry-after-ms": "0",
        });
        response.end(JSON.stringify({ error: { code: "server_error", message: "first failure" } }));
        return;
      }
      if (requestCount === 2) {
        response.socket?.destroy(new Error("second request network failure"));
        return;
      }
      const item = {
        id: "msg-third",
        type: "message",
        role: "assistant",
        content: [{ type: "output_text", text: "Unexpected third response.", annotations: [] }],
        status: "completed",
      };
      const events = [
        { type: "response.output_item.added", output_index: 0, item },
        { type: "response.output_item.done", output_index: 0, item },
        {
          type: "response.completed",
          response: {
            id: "response-third",
            status: "completed",
            output: [item],
            usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 },
          },
        },
      ];
      response.writeHead(200, { "content-type": "text/event-stream" });
      response.end(events.map((event) => `data: ${JSON.stringify(event)}\n\n`).join(""));
    });
    await new Promise<void>((resolve) => apiServer.listen(0, "127.0.0.1", resolve));
    const { port } = apiServer.address() as AddressInfo;
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-shared-retry-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );
    const authPayload = Buffer.from(
      JSON.stringify({ "https://api.openai.com/auth": { chatgpt_account_id: "test" } }),
    ).toString("base64url");

    try {
      const result = await agent.streamFn(
        { ...agent.state.model, baseUrl: `http://127.0.0.1:${port}` },
        { systemPrompt: "Test", messages: [] },
        { apiKey: `e30.${authPayload}.x`, transport: "sse" },
      ).result();
      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(requestCount).toBe(2);
      expect(result.stopReason).toBe("error");
      expect(result.errorMessage).toContain("fetch failed");
      expect(result.errorMessage).not.toContain("Unexpected third response");
    } finally {
      await new Promise<void>((resolve, reject) => {
        apiServer.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });

  it.each([
    "Codex error: HTTP 400 internal server error",
    "Codex error: HTTP 401 internal server error",
    "Codex error: insufficient_quota",
  ])("does not retry a streamed permanent Codex error: %s", async (errorMessage) => {
    const faux = registerFauxProvider();
    registrations.push(faux);
    faux.setResponses([
      fauxAssistantMessage([], { stopReason: "error", errorMessage }),
      fauxAssistantMessage("Unexpected retry."),
    ]);
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-streamed-permanent-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );

    const response = await agent.streamFn(
      faux.getModel(),
      { systemPrompt: "Test", messages: [] },
      { apiKey: "test-token" },
    ).result();

    expect(faux.state.callCount).toBe(1);
    expect(faux.getPendingResponseCount()).toBe(1);
    expect(response.errorMessage).toBe(errorMessage);
  });

  it("retries one network failure", async () => {
    const faux = registerFauxProvider();
    registrations.push(faux);
    faux.setResponses([
      () => {
        throw new Error("fetch failed");
      },
      fauxAssistantMessage("Recovered response."),
    ]);
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-network-retry-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );

    const response = await agent.streamFn(
      faux.getModel(),
      { systemPrompt: "Test", messages: [] },
      { apiKey: "test-token" },
    ).result();

    expect(faux.state.callCount).toBe(2);
    expect(response.content).toEqual([{ type: "text", text: "Recovered response." }]);
  });

  it("does not retry an aborted Codex request", async () => {
    const faux = registerFauxProvider();
    registrations.push(faux);
    faux.setResponses([
      fauxAssistantMessage([], {
        stopReason: "error",
        errorMessage: "Codex error: HTTP 500 upstream",
      }),
      fauxAssistantMessage("Unexpected retry."),
    ]);
    const controller = new AbortController();
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-abort-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );
    const stream = agent.streamFn(
      faux.getModel(),
      { systemPrompt: "Test", messages: [] },
      { apiKey: "test-token", signal: controller.signal },
    );

    await vi.waitFor(() => expect(faux.state.callCount).toBe(1));
    await new Promise<void>((resolve) => setImmediate(resolve));
    controller.abort();
    const response = await stream.result();

    expect(faux.state.callCount).toBe(1);
    expect(faux.getPendingResponseCount()).toBe(1);
    expect(response.stopReason).toBe("aborted");
  });

  it("discards failed tool-call events before retrying", async () => {
    const faux = registerFauxProvider();
    registrations.push(faux);
    faux.setResponses([
      fauxAssistantMessage(fauxToolCall("search_bookmarks", { query: "discarded" }), {
        stopReason: "error",
        errorMessage: "Codex error: HTTP 500 upstream",
      }),
      fauxAssistantMessage("Recovered without a tool call."),
    ]);
    const template = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-tool-template",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );
    const bridgeCall = vi.fn();
    const runtime = new AgentRuntime(
      { call: bridgeCall } as unknown as BridgeClient,
      (_configuration, tools, sessionId) =>
        new Agent({
          sessionId,
          initialState: {
            systemPrompt: "Test agent",
            model: faux.getModel(),
            thinkingLevel: "off",
            tools,
          },
          streamFn: template.streamFn,
        }),
    );

    const response = await runtime.prompt({
      sessionId: "codex-tool-events-session",
      message: "Test",
      configuration: { provider: "openai-codex", model: "gpt-5.4-mini" },
    });

    expect(faux.state.callCount).toBe(2);
    expect(bridgeCall).not.toHaveBeenCalled();
    expect(response.answer).toBe("Recovered without a tool call.");
  });

  it("returns a thrown second-attempt failure instead of replaying the first error", async () => {
    const sourceId = "codex-second-attempt-throw";
    let requestCount = 0;
    const firstFailure = fauxAssistantMessage([], {
      stopReason: "error",
      errorMessage: "Codex error: HTTP 500 first attempt",
    });
    const provider = {
      api: sourceId,
      stream: () => {
        requestCount += 1;
        const stream = createAssistantMessageEventStream();
        if (requestCount === 1) {
          queueMicrotask(() => {
            stream.push({ type: "start", partial: firstFailure });
            stream.push({ type: "error", reason: "error", error: firstFailure });
          });
        } else {
          stream[Symbol.asyncIterator] = async function* () {
            throw new Error("second attempt exploded");
          };
        }
        return stream;
      },
    };
    registerApiProvider({ ...provider, streamSimple: provider.stream }, sourceId);
    registrations.push({ unregister: () => unregisterApiProviders(sourceId) });
    const agent = createPiAgent(
      { provider: "openai-codex", model: "gpt-5.4-mini" },
      [],
      "codex-second-throw-session",
      {
        getAccessToken: vi.fn(async () => "codex-access-token"),
        status: vi.fn(),
        startLogin: vi.fn(),
        disconnect: vi.fn(),
      },
    );

    const response = await agent.streamFn(
      { ...agent.state.model, api: sourceId },
      { systemPrompt: "Test", messages: [] },
      { apiKey: "test-token" },
    ).result();

    expect(requestCount).toBe(2);
    expect(response.stopReason).toBe("error");
    expect(response.errorMessage).toBe("second attempt exploded");
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
