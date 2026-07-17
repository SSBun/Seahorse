import { Agent, type AgentTool } from "@earendil-works/pi-agent-core";
import { Type, type Model, type Static, type TSchema } from "@earendil-works/pi-ai";
import { getBuiltinModels } from "@earendil-works/pi-ai/providers/all";
import type { BridgeClient, BridgePayload } from "./bridgeClient.js";
import type { CodexAuthLike } from "./codexAuth.js";

export interface OpenAICompatibleAgentConfiguration {
  provider: "openai-compatible";
  apiToken: string;
  apiBaseURL: string;
  model: string;
}

export interface ClaudeCompatibleAgentConfiguration {
  provider: "claude-compatible";
  apiToken: string;
  apiBaseURL: string;
  model: string;
}

export interface CodexAgentConfiguration {
  provider: "openai-codex";
  model: string;
}

export type AgentConfiguration =
  | OpenAICompatibleAgentConfiguration
  | ClaudeCompatibleAgentConfiguration
  | CodexAgentConfiguration;

export interface AgentPromptRequest {
  sessionId: string;
  message: string;
  configuration: AgentConfiguration;
}

export interface AgentPromptResponse {
  answer: string;
  bookmarkIds: string[];
}

interface AgentToolDetails {
  bookmarkIds: string[];
}

interface AgentSession {
  agent: Agent;
  configurationKey: string;
}

export type AgentFactory = (
  configuration: AgentConfiguration,
  tools: AgentTool[],
  sessionId: string,
  codexAuth?: CodexAuthLike,
) => Agent;

const systemPrompt = `You are Seahorse's bookmark agent.
Use the available tools to search and inspect the user's bookmarks, tags, and categories.
Never claim a bookmark exists unless a tool returned it.
Answer concisely in the same language as the user.
You have read-only access and cannot create, update, or delete data.`;

/** Owns in-memory Pi agent sessions and routes their tools through the Swift bridge. */
export class AgentRuntime {
  private readonly sessions = new Map<string, AgentSession>();

  constructor(
    private readonly bridge: BridgeClient,
    private readonly createAgent: AgentFactory = createPiAgent,
    private readonly codexAuth?: CodexAuthLike,
  ) {}

  async prompt(request: AgentPromptRequest): Promise<AgentPromptResponse> {
    const session = this.session(request);
    const bookmarkIds = new Set<string>();
    const unsubscribe = session.agent.subscribe((event) => {
      if (event.type !== "tool_execution_end" || event.isError) return;
      const details = event.result?.details as AgentToolDetails | undefined;
      for (const id of details?.bookmarkIds ?? []) {
        bookmarkIds.add(id);
      }
    });

    try {
      await session.agent.prompt(request.message);
    } finally {
      unsubscribe();
    }

    const message = [...session.agent.state.messages]
      .reverse()
      .find((candidate) => candidate.role === "assistant");
    if (!message || message.role !== "assistant") {
      throw new Error("Agent returned no assistant response");
    }
    if (message.errorMessage) {
      throw new Error(message.errorMessage);
    }

    const answer = message.content
      .filter((block) => block.type === "text")
      .map((block) => block.text)
      .join("\n")
      .trim();
    if (!answer) {
      throw new Error("Agent returned an empty response");
    }

    return { answer, bookmarkIds: [...bookmarkIds] };
  }

  private session(request: AgentPromptRequest): AgentSession {
    const configurationKey = JSON.stringify(request.configuration);
    const current = this.sessions.get(request.sessionId);
    if (current?.configurationKey === configurationKey) {
      return current;
    }

    const agent = this.createAgent(
      request.configuration,
      createReadOnlyAgentTools(this.bridge),
      request.sessionId,
      this.codexAuth,
    );
    const session = { agent, configurationKey };
    this.sessions.set(request.sessionId, session);
    return session;
  }
}

/** Creates the read-only tools that a Seahorse Agent may call. */
export function createReadOnlyAgentTools(bridge: BridgeClient): AgentTool[] {
  return [
    createBridgeTool(
      bridge,
      "search_bookmarks",
      "Search bookmarks",
      "Search bookmarks by text and optional filters. Use this before answering discovery questions.",
      Type.Object({
        query: Type.Optional(Type.String({ description: "Text to search for" })),
        limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 20 })),
        offset: Type.Optional(Type.Integer({ minimum: 0 })),
        categoryId: Type.Optional(Type.String({ format: "uuid" })),
        tagIds: Type.Optional(Type.Array(Type.String({ format: "uuid" }))),
        favoriteOnly: Type.Optional(Type.Boolean()),
      }),
      true,
    ),
    createBridgeTool(
      bridge,
      "get_bookmark",
      "Get bookmark",
      "Read full details for one bookmark by id.",
      Type.Object({ id: Type.String({ format: "uuid" }) }),
      true,
    ),
    createBridgeTool(
      bridge,
      "get_bookmarks",
      "Get bookmarks",
      "Read full details for multiple bookmarks by id.",
      Type.Object({
        ids: Type.Array(Type.String({ format: "uuid" }), { minItems: 1, maxItems: 20 }),
      }),
      true,
    ),
    createBridgeTool(
      bridge,
      "list_tags",
      "List tags",
      "List the user's bookmark tags.",
      Type.Object({}),
    ),
    createBridgeTool(
      bridge,
      "search_tags",
      "Search tags",
      "Search bookmark tags by name.",
      Type.Object({ query: Type.Optional(Type.String()) }),
    ),
    createBridgeTool(
      bridge,
      "list_categories",
      "List categories",
      "List the user's bookmark categories.",
      Type.Object({}),
    ),
    createBridgeTool(
      bridge,
      "search_categories",
      "Search categories",
      "Search bookmark categories by name.",
      Type.Object({ query: Type.Optional(Type.String()) }),
    ),
  ];
}

export function createPiAgent(
  configuration: AgentConfiguration,
  tools: AgentTool[],
  sessionId: string,
  codexAuth?: CodexAuthLike,
): Agent {
  if (configuration.provider === "openai-codex") {
    const model = getBuiltinModels("openai-codex").find(
      (candidate) => candidate.id === configuration.model,
    );
    if (!model) {
      throw new Error(`Unsupported Codex model: ${configuration.model}`);
    }
    if (!codexAuth) {
      throw new Error("Codex authentication is unavailable");
    }

    return new Agent({
      sessionId,
      initialState: {
        systemPrompt,
        model,
        thinkingLevel: "low",
        tools,
      },
      getApiKey: () => codexAuth.getAccessToken(),
    });
  }

  if (configuration.provider === "claude-compatible") {
    const model: Model<"anthropic-messages"> = {
      id: configuration.model,
      name: configuration.model,
      api: "anthropic-messages",
      provider: "seahorse-claude-compatible",
      baseUrl: configuration.apiBaseURL.replace(/\/+$/, ""),
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 200_000,
      maxTokens: 4_096,
    };

    return new Agent({
      sessionId,
      initialState: {
        systemPrompt,
        model,
        thinkingLevel: "off",
        tools,
      },
      getApiKey: () => configuration.apiToken,
    });
  }

  const model: Model<"openai-completions"> = {
    id: configuration.model,
    name: configuration.model,
    api: "openai-completions",
    provider: "seahorse-openai-compatible",
    baseUrl: configuration.apiBaseURL.replace(/\/+$/, ""),
    compat: {
      supportsStore: false,
      supportsDeveloperRole: false,
      supportsReasoningEffort: false,
      supportsUsageInStreaming: false,
      maxTokensField: "max_tokens",
      supportsStrictMode: false,
      supportsLongCacheRetention: false,
    },
    reasoning: false,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 128_000,
    maxTokens: 4_096,
  };

  return new Agent({
    sessionId,
    initialState: {
      systemPrompt,
      model,
      thinkingLevel: "off",
      tools,
    },
    getApiKey: () => configuration.apiToken,
  });
}

function createBridgeTool<TParameters extends TSchema>(
  bridge: BridgeClient,
  name: string,
  label: string,
  description: string,
  parameters: TParameters,
  returnsBookmarks = false,
): AgentTool<TParameters, AgentToolDetails> {
  return {
    name,
    label,
    description,
    parameters,
    execute: async (_toolCallId: string, params: Static<TParameters>) => {
      const result = await bridge.call(name, params as BridgePayload);
      return {
        content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
        details: {
          bookmarkIds: returnsBookmarks ? bookmarkIds(result) : [],
        },
      };
    },
  };
}

function bookmarkIds(value: unknown): string[] {
  const records = Array.isArray(value) ? value : [value];
  return records.flatMap((record) => {
    if (!record || typeof record !== "object" || !("id" in record)) return [];
    return typeof record.id === "string" ? [record.id] : [];
  });
}
