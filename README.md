# postmesh

**Turn your inbox into a queryable data layer.**

Postmesh is a local-first email engine that syncs Gmail and Outlook to a local
SQLite database, then lets you query, structure, and automate your inbox via a
CLI and deterministic JSON interface built for developers and AI agents.

Release binaries are published as GitHub Release assets. Installer metadata
lives in `artifacts/`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/postmesh-dev/postmesh/refs/tags/latest/install.sh | sh
```

Uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/postmesh-dev/postmesh/refs/tags/latest/uninstall.sh | sh
```

## Quick start

```bash
# Connect a mailbox
postmesh connect --provider gmail

# Sync mail locally
postmesh sync

# List recent messages
postmesh messages list --page.limit 10

# Query with explicit filters
postmesh messages list \
  --filter.from billing@example.com \
  --filter.received_at.gte 2026-06-01T00:00:00Z \
  --filter.query invoice
```

## What Postmesh does

- Syncs Gmail and Outlook mail into a normalized local store
- Queries that local store with explicit structured filters
- Returns predictable JSON for scripts, tools, and agents
- Avoids repeated provider API calls for every lookup

## Command surface

Global flags:

| Flag | Type | Description |
| --- | --- | --- |
| `-o`, `--output` | `json` or `pretty` | Output format. Defaults to `pretty` on a terminal and `json` when piped |
| `--email` | `email` or `all` | Target a specific account or all configured accounts |
| `-f`, `--file` | `path` or `-` | Read input from file or stdin and merge it with CLI flags |

Top-level commands:

- `postmesh connect`
- `postmesh sync`
- `postmesh messages list`
- `postmesh messages get`
- `postmesh thread messages`
- `postmesh compile`
- `postmesh status`
- `postmesh doctor`
- `postmesh help`

Account management:

- `postmesh accounts list`
- `postmesh accounts remove <email>`
- `postmesh accounts update <email> --nickname <name>`

## Mail query interface

`messages list` accepts structured filters through CLI flags or JSON input.

CLI example:

```bash
postmesh messages list \
  --filter.from notifications@example.com \
  --filter.is_read false \
  --sort.field received_at \
  --sort.order desc \
  --page.limit 20
```

JSON example:

```json
{
  "filter": {
    "from": "billing@example.com",
    "query": "invoice",
    "received_at": {
      "gte": "2026-06-01T00:00:00Z"
    }
  },
  "sort": {
    "field": "received_at",
    "order": "desc"
  },
  "page": {
    "limit": 20
  },
  "select": [
    "id",
    "subject",
    "from_email",
    "body_preview",
    "received_at"
  ]
}
```

Run that JSON query with:

```bash
postmesh -f ./mail-query.json messages list
```

Supported `messages list` filters:

| Flag | Description |
| --- | --- |
| `--filter.from` | Sender email address |
| `--filter.to` | Recipient email address |
| `--filter.subject` | Subject keywords |
| `--filter.body` | Body-preview keywords |
| `--filter.received_at.gte` | Received-at lower bound |
| `--filter.received_at.lte` | Received-at upper bound |
| `--filter.is_read` | Read-state filter |
| `--filter.folder` | Folder identifier |
| `--filter.query` | Full-text search query |
| `--filter.labels` | Gmail labels |
| `--sort.field` | `received_at` or `last_modified` |
| `--sort.order` | `asc` or `desc` |
| `--page.limit` | Maximum rows, `1-100` |
| `--page.cursor` | Cursor returned by a previous page |

Pagination:

`messages list` returns a `next_cursor` when more results are available. Pass it
back as `--page.cursor` to fetch the next page.

## Sync

`postmesh sync` keeps the local mailbox state up to date.

Supported flags:

| Flag | Description |
| --- | --- |
| `--full` | Force a full resync instead of incremental provider state |
| `--since` | Sync only messages received at or after a window like `90d` or `2026-06-01` |
| `--email` | Sync one configured account |
| `--show-new` | Show up to `N` newly synced messages in pretty output |

Examples:

```bash
postmesh sync
postmesh sync --since 90d
postmesh sync --email you@example.com --show-new 20
```

## Connect

Start a new OAuth flow:

```bash
postmesh connect --provider gmail
postmesh connect --provider outlook
```

Resume a pending hosted auth session:

```bash
postmesh connect --session <session_id>
postmesh connect --session <session_id> --async
```

`--async` performs a single non-blocking poll and returns `waiting` if the
authorization session is not ready yet.

## Message retrieval

Get one message:

```bash
postmesh messages get <message_id>
```

Get a thread:

```bash
postmesh thread messages --conversation-id <conversation_id>
```

## Natural-language compile

`compile` turns a natural-language query into a structured `MailQuery`.

```bash
postmesh compile "emails from Bob last week about the budget"
```

Compile-specific flags:

| Flag | Description |
| --- | --- |
| `--model` | Enable local AI fallback |
| `--timezone` | IANA timezone for relative date resolution |
| `--now` | Override current time for deterministic testing |
| `--debug` | Include rule and model diagnostics |

## Output shape

Pretty mode is optimized for humans. JSON mode is intended for scripts and
agents.

Example `messages list` JSON:

```json
{
  "messages": [
    {
      "id": "msg_abc123",
      "subject": "Your June invoice",
      "from": "billing@example.com",
      "to": ["you@example.com"],
      "received_at": "2026-06-02T14:30:00Z",
      "snippet": "Your invoice is ready...",
      "is_read": true,
      "folder_id": "inbox",
      "conversation_id": "conv_456"
    }
  ],
  "next_cursor": "opaque-cursor"
}
```

## Releases

- Installer metadata is committed under `artifacts/`
- Versioned binaries are uploaded as GitHub Release assets
- The installer resolves `latest` through `artifacts/latest.json`

Tracked release metadata:

```text
artifacts/
  latest.json
  releases/
    0.1.0.json
    checksums-0.1.0.txt
```
