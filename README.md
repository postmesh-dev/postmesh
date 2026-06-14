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
  --filter.received-at.gte 2026-06-01T00:00:00Z \
  --filter.query invoice

# Define a collection and extract records via a pipeline
postmesh workflows apply --template coupons
postmesh pipelines run coupons

# Query extracted records
postmesh records list --collection coupons \
  --where.data.vendor Acme \
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
| `--namespace` | `text` | Namespace for scoped resource lookup |
| `-f`, `--file` | `path` or `-` | Read input from file or stdin and merge it with CLI flags |
| `--template` | `name` | Use embedded workflow template (for `workflows apply`) |

Resource names take three forms:

| Form | Example |
| --- | --- |
| Short | `my-pipe` |
| Namespace-prefixed | `custom:my-pipe` |
| Fully-qualified | `@namespace/workflow:my-pipe` |

Account management:

- `postmesh connect` — OAuth connect (`--provider gmail|outlook`, `--nickname`)
- `postmesh connect --session <id>` — Complete a pending auth session
- `postmesh connect --session <id> --async` — Single non-blocking poll
- `postmesh accounts list` — List configured accounts
- `postmesh accounts remove` — Remove an account (`--delete-db`, `--delete-records`)
- `postmesh accounts update` — Update nickname
- `postmesh accounts sync` — Sync messages (`--email`, `--full`, `--since 90d`, `--show-new 5`)
- `postmesh sync` — Shortcut for `postmesh accounts sync`

Messages:

- `postmesh messages list` — Search messages with structured filters (`--email`)
- `postmesh messages get` — Get a single message by ID
- `postmesh thread messages` — Get all messages in a thread

Workflows:

- `postmesh workflows validate` — Validate a workflow bundle (`-f file.yaml`)
- `postmesh workflows apply` — Validate and install a workflow bundle
- `postmesh workflows diff` — Show what a bundle would change
- `postmesh workflows export` — Export installed collections and pipelines
- `postmesh workflows templates` — List embedded workflow templates
- `postmesh workflows show-template` — Show an embedded template's YAML

Collections:

- `postmesh collections list` — List installed collections
- `postmesh collections describe` — Show schema, key, indexes, record count
- `postmesh collections create` — Create a standalone collection
- `postmesh collections update` — Update collection definition
- `postmesh collections delete` — Delete a collection (`--keep-records`, `--delete-records`, `--yes`)
- `postmesh collections reindex` — Recreate indexes

Pipelines:

- `postmesh pipelines list` — List installed pipelines
- `postmesh pipelines describe` — Show source, steps, store target
- `postmesh pipelines validate` — Validate a standalone pipeline
- `postmesh pipelines create` — Create a standalone pipeline
- `postmesh pipelines update` — Update pipeline definition
- `postmesh pipelines enable / disable` — Toggle pipeline state
- `postmesh pipelines run` — Execute a pipeline (`--dry-run`, `--debug`, `--reset`, `--runtime.policy`, `--runtime.model`, `--source.limit`)
- `postmesh pipelines reset` — Delete pipeline-produced records by status or run (`--dry-run`, `--status`, `--run-id`, `--yes`)
- `postmesh pipelines delete` — Delete a pipeline

Records:

- `postmesh records list` — Query records in a collection
- `postmesh records get` — Get a single record by key

Other:

- `postmesh doctor` — Run system diagnostics
- `postmesh completion` — Generate shell completion scripts (`--shell bash|zsh`)
- `postmesh version` — Show version
- `postmesh help` — Show usage help

## Mail query interface

`messages list` accepts structured filters through CLI flags or JSON input.

CLI example:

```bash
postmesh messages list \
  --filter.from notifications@example.com \
  --filter.is-read false \
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

Supported `messages list` flags:

| Flag | Description |
| --- | --- |
| `--email` | Target a specific account by email, or `all`/`*` for all accounts |
| `--filter.from` | Sender email address(es) |
| `--filter.to` | Recipient email address(es) |
| `--filter.subject` | Subject keywords |
| `--filter.body` | Body-preview keywords |
| `--filter.received-at.gte` | Received-at lower bound |
| `--filter.received-at.lte` | Received-at upper bound |
| `--filter.is-read` | Read-state filter |
| `--filter.folder` | Folder identifier |
| `--filter.labels` | Gmail labels |
| `--filter.query` | Full-text search query (FTS5) |
| `--sort.field` | `received_at` or `last_modified` |
| `--sort.order` | `asc` or `desc` |
| `--page.limit` | Maximum rows, `1-100` |
| `--page.cursor` | Cursor returned by a previous page |
| `--select` | Field subset (`id`, `subject`, `from_email`, `body_preview`, `received_at`) |

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

This scheme applies to `--where.*`, `--select`, and `--sort.field`.

### Querying records

```bash
# List all records
postmesh records list --collection coupons

# Filter by data field (equality)
postmesh records list --collection coupons --where.data.vendor Acme

# Filter with operators
postmesh records list --collection coupons \
  --where.data.discount-value.gte 20

# Filter by system field
postmesh records list --collection coupons --where.status review

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

Supported `--where.*` operators:

| Suffix | Example | Description |
| --- | --- | --- |
| _(none)_ | `--where.data.vendor Acme` | Equality |
| `.eq` | `--where.data.vendor.eq Acme` | Explicit equality |
| `.ne` | `--where.data.vendor.ne Acme` | Not equal |
| `.gt` | `--where.data.amount.gt 100` | Greater than |
| `.gte` | `--where.data.amount.gte 50` | Greater than or equal |
| `.lt` | `--where.data.amount.lt 200` | Less than |
| `.lte` | `--where.data.amount.lte 150` | Less than or equal |
| `.in` | `--where.data.status.in active,pending` | Member of list |
| `.contains` | `--where.data.vendor.contains acme` | Substring match |
| `.exists` | `--where.data.expiry-date.exists true` | Field presence |

### Getting a single record

```bash
postmesh records get --collection coupons --record-key 'msg1:SAVE20'
```

## Workflows

A workflow bundles a collection and its pipeline together:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/postmesh-dev/postmesh/main/workflow.json
namespace: postmesh
name: coupons
description: Extract coupon codes and discounts from mail.

collections:
  coupons:
    name: coupons
    description: Coupon and promo-code records extracted from email.
    schema:
      vendor:
        type: string
        required: true
        indexed: true
      code:
        type: string
        required: true
        indexed: true
      discount:
        type: string
      discount_value:
        type: number
      expiry_date:
        type: date
        indexed: true
      category:
        type: string
      source_message_id:
        type: string
        required: true
      confidence:
        type: number
    key:
      fields: [source_message_id, code]
    indexes:
      - fields: [vendor]
      - fields: [expiry_date]

pipelines:
  coupons:
    name: coupons
    description: Find checkout coupon codes and extract offer details.
    source:
      query:
        filter:
          query: '"promo code" OR "coupon code" OR "discount code"'
        page:
          limit: 100
      include:
        body: true
    process:
      - classify:
          field: kind
          using: engine
          enum: [coupon, other]
          default: other
          goal: |
            Classify whether this message contains a redeemable checkout code.
      - filter:
          where:
            kind: coupon
      - extract:
          schema: coupons
          using: engine
          evidence: true
          many: true
          goal: |
            Extract vendor, code, discount, expiry_date and category
            from the checkout coupon email.
      - validate:
          require: [vendor, code, source_message_id]
          on_error: review
      - dedupe:
          by: [source_message_id, code]
          strategy: latest
    store:
      collection: coupons
      mode: upsert
      review_if_confidence_below: 0.65
    runtime:
      policy: semantic
```

```bash
# Apply from a YAML file
postmesh workflows apply -f coupon-vault.yaml

# Or use an embedded template
postmesh workflows apply --template coupons
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
      "account": "you@example.com",
      "subject": "Your June invoice",
      "from": "billing@example.com",
      "to": ["you@example.com"],
      "received_at": "2026-06-02T14:30:00Z",
      "snippet": "Your invoice is ready...",
      "is_read": true,
      "folder_id": "inbox"
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
      "updated_at": "2026-06-07T12:00:00Z",
      "confidence": 0.92,
      "source": {
        "message_id": "msg_abc123"
      },
      "pipeline": {
        "name": "coupons"
      }
    }
  ],
  "page": {
    "limit": 50,
    "next_cursor": "opaque-cursor",
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
