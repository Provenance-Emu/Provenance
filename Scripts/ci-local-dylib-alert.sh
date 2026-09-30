#!/usr/bin/env bash
#
# Open, update or close the tracking issue for CI builds that lack a locally-built
# core dylib (a `local: true` core in CoresRetro/RetroArch/scripts/cores.yml).
#
# Shared by build.yml (alpha releases) and testflight.yml so both raise the same
# alert: one open issue labelled missing-local-dylibs, assigned so GitHub emails,
# commented on by each later incomplete build, closed by the next complete one.
#
# Usage: ci-local-dylib-alert.sh <build> <missing> [outcome]
#   build    what was built, e.g. "Alpha `abc1234`" (markdown)
#   missing  the missing dylibs as one string; empty means the build was complete
#   outcome  what happened to the build, e.g. "It was published anyway."
#
# Env: GH_TOKEN (issues: write), REPO, RUN_URL, ASSIGNEE (optional).

set -euo pipefail

BUILD="$1"
MISSING="$2"
OUTCOME="${3:-}"
LABEL="missing-local-dylibs"

OPEN=$(gh issue list --repo "${REPO}" --label "${LABEL}" --state open \
    --json number --jq '.[0].number // empty' 2>/dev/null || true)

if [ -z "${MISSING}" ]; then
    if [ -n "${OPEN}" ]; then
        gh issue close "${OPEN}" --repo "${REPO}" \
            --comment "${BUILD} has every locally-built core again ([CI run](${RUN_URL}))."
    fi
    exit 0
fi

BODY="${BUILD} is missing these locally-built cores: ${MISSING}. ${OUTCOME}

They are \`local: true\` in \`CoresRetro/RetroArch/scripts/cores.yml\`, so the buildbot never supplies them. Publish them with \`CoresRetro/RetroArch/scripts/local-dylibs.sh upload <core>\`. This issue closes itself on the next complete build. ([CI run](${RUN_URL}))"

if [ -n "${OPEN}" ]; then
    gh issue comment "${OPEN}" --repo "${REPO}" --body "${BODY}"
else
    gh label create "${LABEL}" --repo "${REPO}" --force --color D93F0B \
        --description "A CI build lacked a locally-built core"
    ASSIGN=()
    [ -z "${ASSIGNEE:-}" ] || ASSIGN=(--assignee "${ASSIGNEE}")
    gh issue create --repo "${REPO}" --title "CI builds are missing locally-built cores" \
        --label "${LABEL}" ${ASSIGN[@]+"${ASSIGN[@]}"} --body "${BODY}"
fi
