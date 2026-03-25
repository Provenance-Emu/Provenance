/**
 * Provenance Cheat Proxy — Cloudflare Workers
 *
 * Thin middleware proxy for GameHacking.org cheat lookup.
 *
 * Endpoint:
 *   GET /cheats?title=<title>&system=<slug>
 *
 * Response: JSON array of cheat entries
 *   [{ "name": "...", "code": "...", "category": "General" }, ...]
 *
 * Caching: Results are cached in Cloudflare KV for 24 hours per (title, system) pair.
 *
 * Deployment: See README.md for setup instructions.
 */

// KV binding name — must match wrangler.toml [[kv_namespaces]] binding
const KV_NAMESPACE = "CHEAT_CACHE";
const CACHE_TTL_SECONDS = 24 * 60 * 60; // 24 hours

const GAMEHACKING_BASE = "https://gamehacking.org";
const GAMEHACKING_SEARCH = "https://gamehacking.org/search/";

const USER_AGENT = "Mozilla/5.0 (compatible; Provenance-Emu/1.0; +https://github.com/Provenance-Emu/Provenance)";

// Maximum lengths for KV key inputs — Cloudflare KV keys are limited to 512 bytes
const MAX_TITLE_LENGTH = 200;
const MAX_SYSTEM_LENGTH = 64;

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const origin = request.headers.get("Origin") || "";

        // Handle CORS preflight
        if (request.method === "OPTIONS") {
            return new Response(null, {
                status: 204,
                headers: corsHeaders(origin, env),
            });
        }

        if (url.pathname === "/health") {
            return new Response(JSON.stringify({ status: "ok" }), {
                headers: { "Content-Type": "application/json", ...corsHeaders(origin, env) },
            });
        }

        if (url.pathname !== "/cheats") {
            // Return empty array (200) rather than 404 so clients can always decode an array.
            // The path mismatch is surfaced via a diagnostic header.
            return jsonResponse([], { "X-Validation-Error": "Unknown path — use /cheats" }, origin, env);
        }

        const title = url.searchParams.get("title");
        const system = url.searchParams.get("system") || "";

        if (!title || title.trim() === "") {
            // Return empty array (200) so clients can always decode an array.
            return jsonResponse([], { "X-Validation-Error": "Missing required parameter: title" }, origin, env);
        }

        if (title.trim().length > MAX_TITLE_LENGTH) {
            return jsonResponse([], { "X-Validation-Error": "Parameter too long: title" }, origin, env);
        }

        if (system.length > MAX_SYSTEM_LENGTH) {
            return jsonResponse([], { "X-Validation-Error": "Parameter too long: system" }, origin, env);
        }

        const cacheKey = makeCacheKey(title, system);

        // Check KV cache
        if (env[KV_NAMESPACE]) {
            try {
                const cached = await env[KV_NAMESPACE].get(cacheKey, { type: "json" });
                if (cached !== null) {
                    // X-Proxy-Status: ok signals to clients that the proxy successfully
                    // contacted upstream — an empty array here means "no cheats found",
                    // not a transient error, so clients should skip the direct-scrape fallback.
                    return jsonResponse(cached, { "X-Cache": "HIT", "X-Proxy-Status": "ok" }, origin, env);
                }
            } catch (err) {
                console.error("KV get error:", err);
            }
        }

        // Fetch from GameHacking.org
        let results = [];
        let fetchSucceeded = false;
        try {
            results = await fetchCheats(title, system || null);
            fetchSucceeded = true;
        } catch (err) {
            console.error("Cheat fetch error:", err);
            // Return empty array rather than error — caller falls back to direct scraping
            results = [];
        }

        // Store in KV with TTL only when the upstream fetch succeeded,
        // to avoid caching transient errors as "no cheats" for 24h.
        if (env[KV_NAMESPACE] && fetchSucceeded) {
            ctx.waitUntil(
                env[KV_NAMESPACE].put(cacheKey, JSON.stringify(results), {
                    expirationTtl: CACHE_TTL_SECONDS,
                }).catch((err) => console.error("KV put error:", err))
            );
        }

        // X-Proxy-Status: ok when the upstream fetch succeeded (even with 0 results).
        // X-Proxy-Status: error when the fetch itself threw (network/parse failure).
        // Clients use this to decide whether to fall back to direct scraping.
        return jsonResponse(results, { "X-Cache": "MISS", "X-Proxy-Status": fetchSucceeded ? "ok" : "error" }, origin, env);
    },
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Build CORS response headers.
 * If the `ALLOWED_ORIGINS` env var is set (comma-separated), only matching
 * origins receive `Access-Control-Allow-Origin`; otherwise the wildcard is used.
 */
function corsHeaders(origin, env) {
    const allowed = env.ALLOWED_ORIGINS
        ? env.ALLOWED_ORIGINS.split(",").map((o) => o.trim()).filter(Boolean)
        : [];

    let allowOrigin = "*";
    if (allowed.length > 0) {
        allowOrigin = allowed.includes(origin) ? origin : allowed[0];
    }

    return {
        "Access-Control-Allow-Origin": allowOrigin,
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
        ...(allowed.length > 0 ? { "Vary": "Origin" } : {}),
    };
}

function jsonResponse(data, extraHeaders = {}, origin = "", env = {}) {
    return new Response(JSON.stringify(data), {
        headers: {
            "Content-Type": "application/json",
            "Cache-Control": `public, max-age=${CACHE_TTL_SECONDS}`,
            ...corsHeaders(origin, env),
            ...extraHeaders,
        },
    });
}

/**
 * Truncate a string so that its UTF-8 byte representation fits within maxBytes.
 * Cloudflare KV keys are limited by byte length (512 bytes), not character count,
 * so character-level slicing is insufficient for non-ASCII titles (e.g. CJK, emoji).
 */
function truncateToBytes(str, maxBytes) {
    if (str.length * 4 <= maxBytes) return str; // fast-path: all code-units use ≤4 bytes
    const encoder = new TextEncoder();
    const encoded = encoder.encode(str);
    if (encoded.length <= maxBytes) return str;
    const truncated = encoded.slice(0, maxBytes);
    return new TextDecoder("utf-8", { fatal: false }).decode(truncated);
}

/**
 * Build a KV cache key from title and system.
 * Inputs are truncated by UTF-8 byte length to avoid exceeding Cloudflare KV's
 * 512-byte key limit even for non-ASCII titles (CJK, emoji, etc.).
 */
function makeCacheKey(title, system) {
    const t = truncateToBytes(title.toLowerCase().trim(), MAX_TITLE_LENGTH);
    const s = truncateToBytes((system || "any").toLowerCase().trim(), MAX_SYSTEM_LENGTH);
    return `ghorg::${t}::${s}`;
}

// ─── Scraping ─────────────────────────────────────────────────────────────────

/**
 * Fetch cheats for a given title + optional system slug from GameHacking.org.
 * Returns a normalised array: [{ name, code, category }]
 */
async function fetchCheats(title, systemSlug) {
    // Strategy 1: with system filter
    if (systemSlug) {
        const results = await fetchSearchResults(title, systemSlug);
        if (results.length > 0) return results;
    }

    // Strategy 2: without system filter
    return fetchSearchResults(title, null);
}

async function fetchSearchResults(title, systemSlug) {
    const searchURL = buildSearchURL(title, systemSlug);
    const searchHTML = await fetchHTML(searchURL);
    if (!searchHTML) return [];

    const gamePath = bestGameLink(searchHTML, title);
    if (!gamePath) return [];

    const gameURL = GAMEHACKING_BASE + gamePath;
    const gameHTML = await fetchHTML(gameURL);
    if (!gameHTML) return [];

    return parseCheatPage(gameHTML, title);
}

function buildSearchURL(title, systemSlug) {
    const params = new URLSearchParams({ q: title });
    if (systemSlug) params.set("system", systemSlug);
    return `${GAMEHACKING_SEARCH}?${params.toString()}`;
}

async function fetchHTML(url) {
    try {
        const resp = await fetch(url, {
            headers: {
                "User-Agent": USER_AGENT,
                "Accept": "text/html,application/xhtml+xml",
            },
        });
        if (!resp.ok) return null;
        return await resp.text();
    } catch {
        return null;
    }
}

// ─── Search result parsing ────────────────────────────────────────────────────

/**
 * Extract the best-matching game page path from search results HTML.
 * Returns e.g. "/game/12345" or null.
 */
function bestGameLink(html, title) {
    const patterns = [
        /href="(\/game\/[^"]+)"[^>]*>([^<]{3,80})<\/a>/gi,
        /href="(\/system\/[^"]+)"[^>]*>([^<]{3,80})<\/a>/gi,
    ];

    const links = [];
    for (const pattern of patterns) {
        let m;
        while ((m = pattern.exec(html)) !== null) {
            links.push({ path: m[1], title: decodeHTMLEntities(m[2].trim()) });
        }
        if (links.length > 0) break;
    }

    if (links.length === 0) return null;

    const normTitle = normalise(title);
    let bestLink = null;
    let bestScore = 0.4;

    for (const link of links) {
        const score = diceSimilarity(normTitle, normalise(link.title));
        if (score > bestScore) {
            bestScore = score;
            bestLink = link;
        }
    }

    return bestLink ? bestLink.path : null;
}

// ─── Cheat page parsing ───────────────────────────────────────────────────────

/**
 * Parse a GameHacking.org game page and return normalised cheat entries.
 */
function parseCheatPage(html, romTitle) {
    // Strategy 1: table rows
    let entries = parseTableCheats(html);
    if (entries.length > 0) return entries;

    // Strategy 2: definition lists
    entries = parseDefinitionListCheats(html);
    if (entries.length > 0) return entries;

    // Strategy 3: inline code class spans
    return parseInlineCheats(html);
}

function parseTableCheats(html) {
    const entries = [];
    const trPattern = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
    const tdPattern = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
    const codePattern = /^[0-9A-Fa-f]{4,16}[\s+\-:]*[0-9A-Fa-f]{0,16}$/;

    let trMatch;
    while ((trMatch = trPattern.exec(html)) !== null) {
        const rowHTML = trMatch[1];
        const cells = [];
        let tdMatch;
        tdPattern.lastIndex = 0;
        while ((tdMatch = tdPattern.exec(rowHTML)) !== null) {
            cells.push(stripTags(tdMatch[1]));
        }
        if (cells.length < 2) continue;

        let codeCell = null;
        let nameCell = null;

        for (const cell of cells) {
            const trimmed = cell.trim().replace(/\s+/g, "");
            if (!codeCell && trimmed.length >= 4 && codePattern.test(trimmed)) {
                codeCell = trimmed;
            } else if (!nameCell && cell.trim().length > 0 && cell.trim().length < 200) {
                nameCell = cell.trim();
            }
        }

        if (!codeCell || !nameCell) continue;
        const nameLower = nameCell.toLowerCase();
        if (nameLower === "name" || nameLower === "code" || nameLower === "description") continue;

        entries.push({ name: nameCell, code: codeCell, category: "General" });
    }

    return entries;
}

function parseDefinitionListCheats(html) {
    const entries = [];
    const pattern = /<dt[^>]*>([\s\S]*?)<\/dt>\s*<dd[^>]*>([\s\S]*?)<\/dd>/gi;
    let m;
    while ((m = pattern.exec(html)) !== null) {
        const dt = stripTags(m[1]).trim();
        const dd = stripTags(m[2]).trim();
        if (!dt || !dd) continue;

        const [name, code] = looksLikeCode(dd) ? [dt, dd] : [dd, dt];
        if (!looksLikeCode(code)) continue;

        entries.push({ name, code: code.replace(/\s+/g, ""), category: "General" });
    }
    return entries;
}

function parseInlineCheats(html) {
    const entries = [];
    const pattern = /class="code"[^>]*>([0-9A-Fa-f\s]+)<\/[^>]+>[\s\S]*?class="[^"]*name[^"]*"[^>]*>([^<]{2,80})</gi;
    let m;
    while ((m = pattern.exec(html)) !== null) {
        const code = m[1].trim().replace(/\s+/g, "");
        const name = decodeHTMLEntities(m[2].trim());
        if (!code || !name) continue;
        entries.push({ name, code, category: "General" });
    }
    return entries;
}

// ─── Utility functions ────────────────────────────────────────────────────────

function stripTags(html) {
    return decodeHTMLEntities(html.replace(/<[^>]+>/g, "")).trim();
}

function looksLikeCode(s) {
    const hex = s.trim();
    if (hex.length < 4) return false;
    return /^[0-9A-Fa-f\s+]{4,}$/.test(hex);
}

function normalise(s) {
    return s.toLowerCase()
        .replace(/\(usa\)/g, "")
        .replace(/\(europe\)/g, "")
        .replace(/\(japan\)/g, "")
        .replace(/\(world\)/g, "")
        .trim();
}

function diceSimilarity(a, b) {
    if (a === b) return 1.0;
    const aGrams = bigrams(a);
    const bGrams = bigrams(b);
    if (aGrams.size === 0 || bGrams.size === 0) return 0;

    let intersection = 0;
    let aTotal = 0;
    let bTotal = 0;

    for (const [gram, aCount] of aGrams) {
        aTotal += aCount;
        const bCount = bGrams.get(gram) || 0;
        intersection += Math.min(aCount, bCount);
    }
    for (const bCount of bGrams.values()) {
        bTotal += bCount;
    }

    return 2.0 * intersection / (aTotal + bTotal);
}

function bigrams(s) {
    const freq = new Map();
    for (let i = 0; i < s.length - 1; i++) {
        const gram = s.slice(i, i + 2);
        freq.set(gram, (freq.get(gram) || 0) + 1);
    }
    return freq;
}

function decodeHTMLEntities(s) {
    return s
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&apos;/g, "'")
        .replace(/&nbsp;/g, " ");
}
