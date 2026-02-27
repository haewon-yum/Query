# Glean MCP Configuration

## Status
| Item | Status | Notes |
|------|--------|-------|
| Config file | ✅ | `~/.cursor/mcp.json` exists |
| API Token | ✅ | Valid, tested via curl |
| Search API | ✅ | Working via curl |
| Chat API | ✅ | Working via curl |
| MCP Server | ✅ | Starts correctly (`v0.7.1 running on stdio`) |
| Cursor MCP Integration | ⚠️ Timeout | `ListMcpResources` times out - may need Cursor restart |

**Last tested**: Feb 4, 2026

## Configuration Details
- **Client**: Cursor
- **Instance**: moloco
- **Config File**: `~/.cursor/mcp.json`

## API Endpoints (Moloco Instance)
Base URL: `https://moloco-be.glean.com/rest/api/v1`

| Endpoint | Method | URL |
|----------|--------|-----|
| Search | POST | `https://moloco-be.glean.com/rest/api/v1/search` |
| Chat | POST | `https://moloco-be.glean.com/rest/api/v1/chat` |
| Agents | POST | `https://moloco-be.glean.com/rest/api/v1/agents/runs/wait` |

**Note**: The correct path is `/rest/api/v1/...` (not `/api/v1/...`)

## Setup Command Used
```bash
npx @gleanwork/mcp-server configure \
  --client cursor \
  --token <TOKEN> \
  --instance moloco
```

## Direct API Usage (curl)

### Search
```bash
curl -X POST "https://moloco-be.glean.com/rest/api/v1/search" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"query": "your search query", "pageSize": 10}'
```

### Chat
```bash
curl -X POST "https://moloco-be.glean.com/rest/api/v1/chat" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "fragments": [
          {"text": "Your question here"}
        ]
      }
    ]
  }'
```

## How to Use
1. Restart Cursor after configuration (Cmd+Q to fully quit, then reopen)
2. Agent will have access to Glean search and chat tools
3. You'll be asked for approval when Agent uses these tools

## MCP Tools Exposed
Glean MCP exposes **tools** (not resources):
- `glean_search` - Search across company knowledge
- `glean_chat` - Ask questions with AI-powered answers

To test in Cursor: Ask the agent to "search Glean for [topic]"

## Manual MCP Server Test
```bash
# Verify server starts correctly
GLEAN_INSTANCE=moloco GLEAN_API_TOKEN="<TOKEN>" npx -y @gleanwork/mcp-server server
# Should output: "Glean MCP Server v0.7.1 running on stdio"
```

## Troubleshooting
- If MCP resources timeout, restart Cursor
- Verify configuration exists at `~/.cursor/mcp.json`
- Ensure API token is valid and not expired
- **Important**: Use `/rest/api/v1/` path, not `/api/v1/`
