import { describe, expect, it } from "vitest";
import { z } from "zod";
import { deleteItemShape, getBookmarksShape, searchBookmarksShape, updateBookmarkShape } from "../src/tools.js";

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
