#!/usr/bin/env bash
set -euo pipefail

TOKEN="${1:-}"
URL="${SEAHORSE_MCP_URL:-http://127.0.0.1:17373/mcp}"

if [[ -z "$TOKEN" ]]; then
  echo "usage: scripts/smoke-mcp.sh <mcp-token>" >&2
  exit 64
fi

HEADERS="$(mktemp)"
BODY="$(mktemp)"
trap 'rm -f "$HEADERS" "$BODY"' EXIT

curl -sS -D "$HEADERS" -o "$BODY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"seahorse-smoke","version":"0.1.0"}}}' \
  "$URL"

SESSION_ID="$(awk 'BEGIN{IGNORECASE=1} /^mcp-session-id:/ {gsub("\r",""); print $2}' "$HEADERS" | tail -1)"
if [[ -z "$SESSION_ID" ]]; then
  echo "missing mcp-session-id response header" >&2
  cat "$BODY" >&2
  exit 1
fi

curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
  "$URL" >/dev/null

TOOLS_RESPONSE="$(curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  "$URL")"

printf '%s\n' "$TOOLS_RESPONSE" | node -e '
let input = "";
process.stdin.on("data", chunk => input += chunk);
process.stdin.on("end", () => {
  const dataLines = input
    .split(/\r?\n/)
    .filter(line => line.startsWith("data:"))
    .map(line => line.slice(5).trim());
  if (dataLines.length > 0) {
    input = dataLines.join("\n");
  }
  const json = JSON.parse(input);
  const tools = json.result?.tools?.map(tool => tool.name).sort() ?? [];
  const expected = [
    "create_bookmark",
    "get_bookmark",
    "get_bookmarks",
    "list_categories",
    "list_tags",
    "search_bookmarks",
    "search_categories",
    "search_tags",
    "update_bookmark",
  ].sort();
  const actualText = tools.join("\n");
  const expectedText = expected.join("\n");
  if (actualText !== expectedText) {
    console.error("unexpected tools:");
    console.error(actualText);
    process.exit(1);
  }
  console.log(actualText);
});
'
