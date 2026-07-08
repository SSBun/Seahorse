import { describe, expect, it } from "vitest";
import { BridgeClient } from "../src/bridgeClient.js";

describe("BridgeClient", () => {
  it("sends bearer token and returns bridge result", async () => {
    const calls: unknown[] = [];
    const fetchImpl: typeof fetch = async (url, init) => {
      calls.push({ url, init });
      return new Response(JSON.stringify({ ok: true, result: { id: "1" } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    };

    const client = new BridgeClient("http://127.0.0.1:17374", "secret", fetchImpl);
    await expect(client.call("search_bookmarks", { query: "swift" })).resolves.toEqual({ id: "1" });
    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({
      url: "http://127.0.0.1:17374/bridge",
      init: {
        method: "POST",
        headers: {
          authorization: "Bearer secret",
          "content-type": "application/json",
        },
      },
    });
  });

  it("throws bridge error message", async () => {
    const fetchImpl: typeof fetch = async () =>
      new Response(JSON.stringify({ ok: false, error: { code: "validation_error", message: "bad url" } }), {
        status: 400,
        headers: { "content-type": "application/json" },
      });

    const client = new BridgeClient("http://127.0.0.1:17374", "secret", fetchImpl);
    await expect(client.call("create_bookmark", {})).rejects.toThrow("bad url");
  });
});
