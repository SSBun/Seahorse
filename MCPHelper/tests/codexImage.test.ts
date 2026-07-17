import { describe, expect, it, vi } from "vitest";
import type { CodexAuthLike } from "../src/codexAuth.js";
import { CodexImageGenerator } from "../src/codexImage.js";

describe("CodexImageGenerator", () => {
  it("uses Codex OAuth and extracts the completed image result", async () => {
    const accessToken = jwt({
      "https://api.openai.com/auth": { chatgpt_account_id: "account-1" },
    });
    const auth = {
      getAccessToken: vi.fn(async () => accessToken),
    } as unknown as CodexAuthLike;
    const fetcher = vi.fn(async (_input: string | URL | Request, init?: RequestInit) => {
      const request = JSON.parse(String(init?.body)) as Record<string, unknown>;
      expect(request).toMatchObject({
        model: "gpt-5.4",
        stream: true,
        tools: [{ type: "image_generation", size: "1024x1536" }],
        tool_choice: { type: "image_generation" },
      });
      expect(request.input).toEqual([
        {
          role: "user",
          content: [
            { type: "input_text", text: "A seahorse" },
            { type: "input_image", image_url: "data:image/png;base64,cmVmZXJlbmNl" },
          ],
        },
      ]);
      expect(new Headers(init?.headers).get("chatgpt-account-id")).toBe("account-1");
      return new Response(
        `data: ${JSON.stringify({
          type: "response.output_item.done",
          item: { type: "image_generation_call", result: "aW1hZ2U=" },
        })}\n\ndata: [DONE]\n\n`,
        { status: 200, headers: { "content-type": "text/event-stream" } },
      );
    });

    const result = await new CodexImageGenerator(auth, fetcher).generate(
      "gpt-5.4",
      "A seahorse",
      "cmVmZXJlbmNl",
    );

    expect(result).toEqual({ imageBase64: "aW1hZ2U=" });
    expect(auth.getAccessToken).toHaveBeenCalledOnce();
  });

  it("rejects Codex models without image input support before authentication", async () => {
    const auth = {
      getAccessToken: vi.fn(),
    } as unknown as CodexAuthLike;

    await expect(
      new CodexImageGenerator(auth, vi.fn()).generate("gpt-5.3-codex-spark", "A seahorse"),
    ).rejects.toThrow("does not support image generation");
    expect(auth.getAccessToken).not.toHaveBeenCalled();
  });
});

function jwt(payload: object): string {
  return `header.${Buffer.from(JSON.stringify(payload)).toString("base64url")}.signature`;
}
