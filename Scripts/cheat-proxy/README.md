# Provenance Cheat Proxy

A thin Cloudflare Workers middleware that scrapes [GameHacking.org](https://gamehacking.org)
and returns normalized JSON cheat entries with server-side KV caching (24 h TTL).

## Endpoint

```
GET /cheats?title=<game title>&system=<system slug>
```

**Parameters:**
- `title` (required) — The game title to search for.
- `system` (optional) — The GameHacking.org system slug (e.g. `n64`, `gba`, `gc`).

**Response:**
```json
[
  { "name": "Infinite Lives", "code": "8107A5C02400", "category": "General" },
  { "name": "Max Health",     "code": "8107A5C40064", "category": "General" }
]
```

Returns an empty array `[]` when no cheats are found or when the request is invalid
(e.g. missing `title`, unknown path). The response is always HTTP 200 with a JSON array
so clients can safely decode without checking the status code. Invalid requests also
include an `X-Validation-Error` header with a short description. The caller should fall
back to direct scraping on an empty result.

## Health check

```
GET /health  →  { "status": "ok" }
```

## Deployment (manual — requires a Cloudflare account)

> **Note:** Deployment is manual and requires a free [Cloudflare](https://cloudflare.com)
> account and the [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/).

1. **Install Wrangler:**
   ```bash
   npm install -g wrangler
   wrangler login
   ```

2. **Create the KV namespace:**
   ```bash
   wrangler kv:namespace create CHEAT_CACHE
   ```
   Copy the `id` from the output and paste it into `wrangler.toml` replacing
   `REPLACE_WITH_YOUR_KV_NAMESPACE_ID`.

3. **Deploy:**
   ```bash
   cd Scripts/cheat-proxy
   wrangler deploy
   ```
   Wrangler will print the worker URL, e.g.:
   `https://provenance-cheat-proxy.<your-subdomain>.workers.dev`

4. **Configure the app:**
   Set the proxy URL in Provenance settings (Settings → Cheats → Proxy URL) or
   update the compile-time default in
   `PVLibrary/Sources/PVLibrary/Cheat/GameHackingOrgLookup.swift`:
   ```swift
   static let defaultProxyURL = "https://provenance-cheat-proxy.<your-subdomain>.workers.dev"
   ```

## Local development

```bash
cd Scripts/cheat-proxy
wrangler dev
```

The worker is then available at `http://localhost:8787/cheats?title=Mario&system=n64`.

## Rate limits (Cloudflare free tier)

| Limit            | Value             |
|------------------|-------------------|
| Requests/day     | 100,000           |
| KV reads/day     | 100,000           |
| KV writes/day    | 1,000             |
| CPU time/request | 10 ms (bundled)   |

The 24 h KV cache ensures that repeated lookups for the same title+system pair
use only one KV write per day and hit the fast read path for all subsequent requests.
