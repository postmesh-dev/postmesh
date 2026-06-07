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

The installer downloads both `postmesh` and `postmesh-migrate`, runs the
migration on any existing databases, and places both binaries in
`~/.local/bin/`.

Uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/postmesh-dev/postmesh/refs/tags/latest/uninstall.sh | sh
```

(Keeps your local data by default. Add `--purge` to remove everything.)

## Quick start

```bash
# Connect a mailbox
postmesh connect --provider gmail

# Sync mail locally
postmesh accounts sync

# List recent messages
postmesh messages list --page.limit 10

# Query with explicit filters
postmesh messages list \
  --filter.from billing@example.com \
  --filter.received_at.gte 2026-06-01T00:00:00Z \
  --filter.query invoice

# Define a collection and extract records via a pipeline
postmesh workflows apply -f examples/workflows/coupon-vault.yaml

# Query extracted records
postmesh records list --collection coupons \
  --where 'data.vendor=Acme' \
  --select 'data.code,data.discount'
```

## What Postmesh does

- Syncs Gmail and Outlook mail into a normalized local store
- Queries that local store with explicit structured filters
- Defines pipelines that extract structured records from messages
- Returns predictable JSON for scripts, tools, and agents
- Avoids repeated provider API calls for every lookup

## Command surface

Global flags:

| Flag | Type | Description |
| --- | --- | --- |
| `-o`, `--output` | `json` or `pretty` | Output format. Defaults to `pretty` on a terminal and `json` when piped |
| `--email` | `email` or `all` | Target a specific account or all configured accounts |
| `-f`, `--file` | `path` or `-` | Read input from file or stdin and merge it with CLI flags |

Account management:

- `postmesh accounts add` — OAuth connect (alias for `connect`)
- `postmesh accounts list` — List configured accounts
- `postmesh accounts remove` — Remove an account
- `postmesh accounts update` — Update nickname
- `postmesh accounts sync` — Sync messages for one or all accounts

Messages:

- `postmesh messages list` — Search messages with structured filters
- `postmesh messages get` — Get a single message by ID
- `postmesh thread messages` — Get all messages in a thread

Workflows:

- `postmesh workflows validate` — Validate a workflow bundle (`-f file.yaml`)
- `postmesh workflows apply` — Validate and install a workflow bundle
- `postmesh workflows diff` — Show what a bundle would change
- `postmesh workflows export` — Export installed collections and pipelines

Collections:

- `postmesh collections list` — List installed collections
- `postmesh collections describe` — Show schema, key, indexes, record count
- `postmesh collections create` — Create a standalone collection
- `postmesh collections update` — Update collection definition
- `postmesh collections delete` — Delete a collection
- `postmesh collections reindex` — Recreate indexes

Pipelines:

- `postmesh pipelines list` — List installed pipelines
- `postmesh pipelines describe` — Show source, steps, store target
- `postmesh pipelines validate` — Validate a standalone pipeline
- `postmesh pipelines create` — Create a standalone pipeline
- `postmesh pipelines update` — Update pipeline definition
- `postmesh pipelines enable / disable` — Toggle pipeline state
- `postmesh pipelines run` — Execute a pipeline
- `postmesh pipelines delete` — Delete a pipeline

Records:

- `postmesh records list` — Query records in a collection
- `postmesh records get` — Get a single record by key

Other:

- `postmesh model` — Select or list available AI models
- `postmesh doctor` — Run system diagnostics
- `postmesh help` — Show usage help

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
| `--sort.field` | `received_at` or `last_modified` |
| `--sort.order` | `asc` or `desc` |
| `--page.limit` | Maximum rows, `1-100` |
| `--page.cursor` | Cursor returned by a previous page |

Pagination:

`messages list` returns a `next_cursor` when more results are available. Pass it
back as `--page.cursor` to fetch the next page.

## Collection records

Collections are schemas that describe structured records extracted from email via
pipelines. Pipelines are YAML-defined extractors that classify, filter, map, and
validate fields from matched messages.

### Field path scheme

All record queries use a consistent field path scheme that matches the output
shape:

| Path | Example | Where it resolves |
| --- | --- | --- |
| `data.xxx` | `data.vendor` | Collection data field (from the record's JSON body) |
| `status` | `status` | System status column |
| `source.message_id` | `source.message_id` | Source email reference |
| `pipeline.name` | `pipeline.name` | Pipeline that stored the record |

This scheme applies to `--where`, `--select`, and `--sort.field`.

### Querying records

```bash
# List all records
postmesh records list --collection coupons

# Filter by data field
postmesh records list --collection coupons --where 'data.vendor=Acme'

# Filter with operators
postmesh records list --collection coupons \
  --where 'data.discount_value' '{ "gte": 20 }'

# Filter by system field
postmesh records list --collection coupons --where 'status=review'

# Select specific fields
postmesh records list --collection coupons \
  --select 'data.code,data.vendor,data.discount,status'

# Sort by data field
postmesh records list --collection coupons \
  --sort.field 'data.expiry_date' --sort.order asc

# Pagination
postmesh records list --collection coupons --page.limit 10
postmesh records list --collection coupons --page.cursor <cursor>
```

### Getting a single record

```bash
postmesh records get --collection coupons --record_key 'msg1:SAVE20'
```

## Workflows

A workflow bundles a collection and its pipeline together:

```yaml
name: coupon-vault
collections:
  coupons:
    name: coupons
    schema:
      vendor:
        type: string
        required: true
      code:
        type: string
        required: true
      discount:
        type: string
    key:
      fields: [source_message_id, code]
pipelines:
  coupons:
    name: coupons
    source:
      query:
        filter:
          query: "coupon OR promo OR discount"
    process:
      - classify:
          field: data.kind
          using: regex
          enum: [coupon, promotion, other]
      - filter:
          where:
            data.kind: [coupon, promotion]
      - extract:
          using: regex
          fields:
            data.code:
              input: text
              pattern: '(?:code)[:\s]+([A-Z0-9]+)'
      - validate:
          require: [data.vendor, data.code, data.source_message_id]
    store:
      collection: coupons
```

```bash
postmesh workflows apply -f coupon-vault.yaml
postmesh pipelines run coupons
postmesh records list --collection coupons
```

## Connect

Start a new OAuth flow:

```bash
postmesh connect --provider gmail
postmesh connect --provider outlook
```

**Gmail OAuth verification notice:** Postmesh is awaiting Google OAuth
verification. During Gmail setup, Google may show an unverified-app notice.
Review Google's details before proceeding to Postmesh.

Resume a pending hosted auth session:

```bash
postmesh connect --session <session_id>
postmesh connect --session <session_id> --async
```

`--async` performs a single non-blocking poll and returns `waiting` if the
authorization session is not ready yet.

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

Example `records list` JSON:

```json
{
  "data": [
    {
      "id": "@local/coupon-vault:coupons:msg1:SAVE20",
      "record_key": "msg1:SAVE20",
      "data": {
        "vendor": "Acme Corp",
        "code": "SAVE20",
        "discount": "20% off",
        "offer_url": "https://acme.com/coupon/SAVE20"
      },
      "status": "active",
      "created_at": "2026-06-07T12:00:00Z",
      "updated_at": "2026-06-07T12:00:00Z"
    }
  ],
  "page": {
    "limit": 50,
    "has_more": false
  }
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
