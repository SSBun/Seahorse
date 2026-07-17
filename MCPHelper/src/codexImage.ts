import { getBuiltinModels } from "@earendil-works/pi-ai/providers/all";
import type { CodexAuthLike } from "./codexAuth.js";

export interface CodexImageGeneratorLike {
  generate(model: string, prompt: string, referenceImageBase64?: string): Promise<{ imageBase64: string }>;
}

type Fetch = typeof fetch;

/** Generates one image through the Codex backend using the existing ChatGPT OAuth session. */
export class CodexImageGenerator implements CodexImageGeneratorLike {
  constructor(
    private readonly auth: CodexAuthLike,
    private readonly fetcher: Fetch = fetch,
  ) {}

  async generate(
    model: string,
    prompt: string,
    referenceImageBase64?: string,
  ): Promise<{ imageBase64: string }> {
    const availableModel = getBuiltinModels("openai-codex").find(
      (candidate) => candidate.id === model && candidate.input.includes("image"),
    );
    if (!availableModel) {
      throw new Error(`Codex model does not support image generation: ${model}`);
    }

    const accessToken = await this.auth.getAccessToken();
    const content: Array<
      | { type: "input_text"; text: string }
      | { type: "input_image"; image_url: string }
    > = [{ type: "input_text", text: prompt }];
    if (referenceImageBase64) {
      content.push({
        type: "input_image",
        image_url: `data:image/png;base64,${referenceImageBase64}`,
      });
    }
    const response = await this.fetcher("https://chatgpt.com/backend-api/codex/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "chatgpt-account-id": extractAccountID(accessToken),
        "OpenAI-Beta": "responses=experimental",
        accept: "text/event-stream",
        "content-type": "application/json",
        originator: "pi",
        "user-agent": "Seahorse",
      },
      body: JSON.stringify({
        model,
        store: false,
        stream: true,
        instructions: "Generate the requested image.",
        input: [{ role: "user", content }],
        tools: [{ type: "image_generation", size: "1024x1536" }],
        tool_choice: { type: "image_generation" },
        parallel_tool_calls: false,
      }),
      signal: AbortSignal.timeout(300_000),
    });

    if (!response.ok) {
      throw new Error(`Codex image generation failed with HTTP ${response.status}.`);
    }

    const imageBase64 = imageFromSSE(await response.text());
    if (!imageBase64 || Buffer.from(imageBase64, "base64").length === 0) {
      throw new Error("Codex image generation returned no image data.");
    }
    return { imageBase64 };
  }
}

function extractAccountID(token: string): string {
  try {
    const payload = JSON.parse(Buffer.from(token.split(".")[1] ?? "", "base64url").toString("utf8")) as {
      "https://api.openai.com/auth"?: { chatgpt_account_id?: string };
    };
    const accountID = payload["https://api.openai.com/auth"]?.chatgpt_account_id;
    if (accountID) return accountID;
  } catch {}
  throw new Error("Codex authorization is missing its account ID.");
}

function imageFromSSE(body: string): string | undefined {
  for (const line of body.split(/\r?\n/)) {
    if (!line.startsWith("data:")) continue;
    const data = line.slice(5).trim();
    if (!data || data === "[DONE]") continue;
    try {
      const event = JSON.parse(data) as {
        item?: { type?: string; result?: string };
        response?: { output?: Array<{ type?: string; result?: string }> };
      };
      if (event.item?.type === "image_generation_call" && event.item.result) {
        return event.item.result;
      }
      const output = event.response?.output?.find(
        (item) => item.type === "image_generation_call" && item.result,
      );
      if (output?.result) return output.result;
    } catch {}
  }
  return undefined;
}
