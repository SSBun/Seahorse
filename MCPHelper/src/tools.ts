import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { ToolAnnotations } from "@modelcontextprotocol/sdk/types.js";
import type { BridgeClient } from "./bridgeClient.js";

export const searchBookmarksShape = {
  query: z.string().default(""),
  limit: z.number().int().min(1).max(100).optional(),
  offset: z.number().int().min(0).optional(),
  categoryId: z.string().uuid().optional(),
  tagIds: z.array(z.string().uuid()).optional(),
  favoriteOnly: z.boolean().optional(),
};

const getBookmarkShape = {
  id: z.string().uuid(),
};

export const getBookmarksShape = {
  ids: z.array(z.string().uuid()).min(1).max(100),
};

export const deleteItemShape = {
  id: z.string().uuid(),
};

const createBookmarkShape = {
  url: z.string().min(1),
  title: z.string().optional(),
  notes: z.string().nullable().optional(),
  categoryId: z.string().uuid().optional(),
  tagIds: z.array(z.string().uuid()).optional(),
  isFavorite: z.boolean().optional(),
};

export const updateBookmarkShape = {
  id: z.string().uuid(),
  title: z.string().optional(),
  url: z.string().optional(),
  notes: z.string().nullable().optional(),
  categoryId: z.string().uuid().optional(),
  tagIds: z.array(z.string().uuid()).optional(),
  isFavorite: z.boolean().optional(),
  posterImageURL: z.string().url().optional(),
  posterImagePath: z.string().min(1).optional(),
};

const searchNameShape = {
  query: z.string().default(""),
};

export function registerTools(server: McpServer, bridge: BridgeClient): void {
  registerBridgeTool(server, bridge, "search_bookmarks", searchBookmarksShape);
  registerBridgeTool(server, bridge, "get_bookmark", getBookmarkShape);
  registerBridgeTool(server, bridge, "get_bookmarks", getBookmarksShape);
  registerBridgeTool(server, bridge, "create_bookmark", createBookmarkShape);
  registerBridgeTool(server, bridge, "update_bookmark", updateBookmarkShape);
  registerBridgeTool(server, bridge, "delete_item", deleteItemShape, { destructiveHint: true });
  registerBridgeTool(server, bridge, "list_tags", {});
  registerBridgeTool(server, bridge, "search_tags", searchNameShape);
  registerBridgeTool(server, bridge, "delete_tag", deleteItemShape, { destructiveHint: true });
  registerBridgeTool(server, bridge, "list_categories", {});
  registerBridgeTool(server, bridge, "search_categories", searchNameShape);
}

function registerBridgeTool<TShape extends z.ZodRawShape>(
  server: McpServer,
  bridge: BridgeClient,
  name: string,
  shape: TShape,
  annotations: ToolAnnotations = {},
): void {
  server.registerTool(name, { inputSchema: z.object(shape), annotations }, async (args) => {
    const result = await bridge.call(name, args);
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  });
}
