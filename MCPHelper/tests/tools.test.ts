import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import type { BridgeClient } from "../src/bridgeClient.js";
import {
  deleteItemShape,
  getBookmarksShape,
  registerTools,
  searchBookmarksShape,
  updateBookmarkShape,
} from "../src/tools.js";

const deleteItemSchema = z.object(deleteItemShape);
const searchBookmarksSchema = z.object(searchBookmarksShape);
const getBookmarksSchema = z.object(getBookmarksShape);
const updateBookmarkSchema = z.object(updateBookmarkShape);

describe("search_bookmarks schema", () => {
  it("accepts non-negative offset for pagination", () => {
    expect(searchBookmarksSchema.parse({ query: "", limit: 100, offset: 200 })).toMatchObject({
      query: "",
      limit: 100,
      offset: 200,
    });
    expect(() => searchBookmarksSchema.parse({ offset: -1 })).toThrow();
  });
});

describe("get_bookmarks schema", () => {
  it("requires 1 to 100 bookmark ids", () => {
    const id = "00000000-0000-4000-8000-000000000000";

    expect(getBookmarksSchema.parse({ ids: [id] })).toEqual({ ids: [id] });
    expect(() => getBookmarksSchema.parse({ ids: [] })).toThrow();
    expect(() => getBookmarksSchema.parse({ ids: Array(101).fill(id) })).toThrow();
  });
});

describe("update_bookmark schema", () => {
  it("accepts remote and local poster image inputs", () => {
    const id = "00000000-0000-4000-8000-000000000000";

    expect(updateBookmarkSchema.parse({ id, posterImageURL: "https://example.com/poster.png" })).toMatchObject({
      id,
      posterImageURL: "https://example.com/poster.png",
    });
    expect(updateBookmarkSchema.parse({ id, posterImagePath: "/Users/me/poster.png" })).toMatchObject({
      id,
      posterImagePath: "/Users/me/poster.png",
    });
  });
});

describe("delete_item schema", () => {
  it("requires an item id", () => {
    const id = "00000000-0000-4000-8000-000000000000";

    expect(deleteItemSchema.parse({ id })).toEqual({ id });
    expect(() => deleteItemSchema.parse({ id: "not-an-id" })).toThrow();
  });
});

describe("tool registration", () => {
  it("invokes parameterized and zero-argument handlers and preserves annotations", async () => {
    const call = vi.fn(async (name: string, args: Record<string, unknown>) => ({ name, args }));
    const server = new McpServer({ name: "test-server", version: "1.0.0" });
    registerTools(server, { call } as unknown as BridgeClient);

    const client = new Client({ name: "test-client", version: "1.0.0" });
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

    const searchResult = await client.callTool({ name: "search_bookmarks", arguments: {} });
    expect(searchResult.isError).not.toBe(true);
    expect(call).toHaveBeenCalledWith("search_bookmarks", { query: "" });

    const tagsResult = await client.callTool({ name: "list_tags", arguments: {} });
    expect(tagsResult.isError).not.toBe(true);
    expect(call).toHaveBeenCalledWith("list_tags", {});

    const tagId = "00000000-0000-4000-8000-000000000000";
    const deleteTagResult = await client.callTool({ name: "delete_tag", arguments: { id: tagId } });
    expect(deleteTagResult.isError).not.toBe(true);
    expect(call).toHaveBeenCalledWith("delete_tag", { id: tagId });

    const tools = await client.listTools();
    expect(tools.tools.find((tool) => tool.name === "delete_item")?.annotations?.destructiveHint).toBe(true);
    expect(tools.tools.find((tool) => tool.name === "delete_tag")?.annotations?.destructiveHint).toBe(true);

    call.mockRejectedValueOnce(new Error("bridge unavailable"));
    const errorResult = await client.callTool({ name: "list_categories", arguments: {} });
    expect(errorResult.isError).toBe(true);

    await Promise.all([client.close(), server.close()]);
  });
});
