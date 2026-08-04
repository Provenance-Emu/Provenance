#!/usr/bin/env bash
# secrets-1p.sh — keep CI secrets in sync: 1Password <-> .env <-> GitHub.
#
# GitHub Actions secrets are WRITE-ONLY: nothing can ever read them back, so
# when a runner needs a value you don't have locally, it is gone. This script
# makes 1Password the durable copy and .env the local working copy.
#
#   ./secrets-1p.sh push     # .env  -> 1Password item (creates/updates fields)
#   ./secrets-1p.sh pull     # 1Password item -> .env  (fills blanks, never clobbers non-empty)
#   ./secrets-1p.sh gh       # .env  -> GitHub repo secrets (only non-empty keys)
#   ./secrets-1p.sh status   # what's set where (never prints values)
#
# Config (env overrides):
#   OP_ITEM   default "Provenance GitHub CI"   (item title in 1Password)
#   OP_VAULT  default "Private"
#   GH_REPO   default Provenance-Emu/Provenance
#
# First-time 1Password CLI setup (one time):
#   1Password app -> Settings -> Developer -> "Integrate with 1Password CLI"
#   then any `op` command will prompt via Touch ID.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
OP_ITEM="${OP_ITEM:-Provenance GitHub CI}"
OP_VAULT="${OP_VAULT:-Private}"
GH_REPO="${GH_REPO:-Provenance-Emu/Provenance}"

die() { echo "error: $*" >&2; exit 1; }

# Keys managed here = union of what .env.sample documents and CI references.
KEYS=(
    ASC_API_KEY_ID ASC_API_ISSUER_ID ASC_API_KEY_PATH
    CERT_P12 P12_PASS SIGNING_IDENTITY
    DYLIBS_TOKEN WEBSITE_DISPATCH_TOKEN
    DISCORD_WEBHOOK ANTHROPIC_API_KEY
    APPLE_ID ITC_TEAM_ID DEV_TEAM_ID DEV_DOMAIN
)
# Local-only keys that must never be pushed as GitHub secrets.
GH_SKIP=(ASC_API_KEY_PATH APPLE_ID DEV_DOMAIN)

env_get() { sed -n "s/^$1=//p" "$ENV_FILE" 2>/dev/null | head -1; }

need_op() {
    command -v op >/dev/null || die "1Password CLI (op) not installed: brew install 1password-cli"
    op whoami >/dev/null 2>&1 || die "op not signed in — enable CLI integration in the 1Password app (Settings > Developer), then re-run"
}

cmd_push() {
    need_op; [ -f "$ENV_FILE" ] || die "no .env — copy .env.sample first"
    if ! op item get "$OP_ITEM" --vault "$OP_VAULT" >/dev/null 2>&1; then
        echo "creating 1Password item '$OP_ITEM' in vault '$OP_VAULT'"
        op item create --category "API Credential" --title "$OP_ITEM" --vault "$OP_VAULT" \
            --tags provenance,ci >/dev/null
    fi
    local args=() n=0
    for k in "${KEYS[@]}"; do
        local v; v="$(env_get "$k")"
        [ -n "$v" ] || continue
        args+=("$k[concealed]=$v"); n=$((n+1))
    done
    [ $n -gt 0 ] || die "nothing to push — .env has no non-empty managed keys"
    op item edit "$OP_ITEM" --vault "$OP_VAULT" "${args[@]}" >/dev/null
    echo "pushed $n field(s) to 1Password item '$OP_ITEM'"
}

cmd_pull() {
    need_op; [ -f "$ENV_FILE" ] || cp "$REPO_ROOT/.env.sample" "$ENV_FILE"
    local n=0
    for k in "${KEYS[@]}"; do
        local cur; cur="$(env_get "$k")"
        [ -z "$cur" ] || continue                      # never clobber local values
        local v
        v="$(op item get "$OP_ITEM" --vault "$OP_VAULT" --fields "label=$k" --reveal 2>/dev/null)" || continue
        [ -n "$v" ] || continue
        if grep -q "^$k=" "$ENV_FILE"; then
            # BSD sed -i needs a suffix arg; use a temp file to stay portable.
            awk -v k="$k" -v v="$v" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v} {print}' \
                "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        else
            printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
        fi
        n=$((n+1))
    done
    chmod 600 "$ENV_FILE"
    echo "filled $n blank key(s) in .env from 1Password"
}

cmd_gh() {
    [ -f "$ENV_FILE" ] || die "no .env"
    command -v gh >/dev/null || die "gh CLI required"
    local n=0
    for k in "${KEYS[@]}"; do
        case " ${GH_SKIP[*]} " in *" $k "*) continue ;; esac
        local v; v="$(env_get "$k")"
        [ -n "$v" ] || continue
        printf '%s' "$v" | gh secret set "$k" -R "$GH_REPO"
        n=$((n+1))
    done
    echo "set $n GitHub secret(s) on $GH_REPO (empty keys skipped)"
}

cmd_status() {
    printf '%-24s %-6s %-10s %s\n' "KEY" ".env" "1Password" "GitHub"
    local ghlist=""; ghlist="$(gh secret list -R "$GH_REPO" 2>/dev/null | cut -f1)" || true
    local opok=false; op whoami >/dev/null 2>&1 && opok=true
    for k in "${KEYS[@]}"; do
        local e="-" o="-" g="-"
        [ -n "$(env_get "$k")" ] && e="set"
        if $opok; then
            op item get "$OP_ITEM" --vault "$OP_VAULT" --fields "label=$k" >/dev/null 2>&1 && o="set"
        else o="?"; fi
        grep -qx "$k" <<<"$ghlist" && g="set"
        printf '%-24s %-6s %-10s %s\n' "$k" "$e" "$o" "$g"
    done
    $opok || echo "(1Password: not signed in — enable CLI integration in the app)"
}

case "${1:-}" in
    push)   cmd_push ;;
    pull)   cmd_pull ;;
    gh)     cmd_gh ;;
    status) cmd_status ;;
    *) sed -n '2,24p' "$0"; exit 1 ;;
esac
