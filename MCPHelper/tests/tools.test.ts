import { describe, expect, it } from "vitest";
import { z } from "zod";
import { getBookmarksShape, searchBookmarksShape } from "../src/tools.js";

const searchBookmarksSchema = z.object(searchBookmarksShape);
const getBookmarksSchema = z.object(getBookmarksShape);

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
