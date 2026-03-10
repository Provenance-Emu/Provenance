#!/usr/bin/env bash
# setup-github-project.sh — One-time setup of the "Provenance Roadmap" GitHub Project v2
#
# Prerequisites:
#   gh auth refresh -s project   (adds the project OAuth scope)
#   gh auth status               (verify project scope is listed)
#
# Usage: ./Scripts/setup-github-project.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}▶${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*" >&2; }

REPO="${GITHUB_REPOSITORY:-Provenance-Emu/Provenance}"
ORG="${REPO%%/*}"
PROJECT_TITLE="Provenance Roadmap"

# ── Check project scope ───────────────────────────────────────────────────────
info "Checking gh auth scopes..."
if ! gh auth status 2>&1 | grep -q "project"; then
    error "Missing 'project' scope. Run: gh auth refresh -s project"
    exit 1
fi
success "Project scope available"

# ── Get org node ID ───────────────────────────────────────────────────────────
info "Getting org node ID for '$ORG'..."
ORG_ID=$(gh api graphql -f query="{ organization(login: \"$ORG\") { id } }" --jq '.data.organization.id')
success "Org ID: $ORG_ID"

# ── Create project ────────────────────────────────────────────────────────────
info "Creating project '$PROJECT_TITLE'..."
PROJECT_RESULT=$(gh api graphql -f query='
  mutation($ownerId: ID!, $title: String!) {
    createProjectV2(input: {ownerId: $ownerId, title: $title}) {
      projectV2 { id number url }
    }
  }
' -f ownerId="$ORG_ID" -f title="$PROJECT_TITLE")

PROJECT_ID=$(echo "$PROJECT_RESULT" | jq -r '.data.createProjectV2.projectV2.id')
PROJECT_NUM=$(echo "$PROJECT_RESULT" | jq -r '.data.createProjectV2.projectV2.number')
PROJECT_URL=$(echo "$PROJECT_RESULT" | jq -r '.data.createProjectV2.projectV2.url')
success "Project created: $PROJECT_URL (number: $PROJECT_NUM)"

# ── Make project public ───────────────────────────────────────────────────────
info "Making project public..."
gh api graphql -f query='
  mutation($projectId: ID!) {
    updateProjectV2(input: {projectId: $projectId, public: true}) {
      projectV2 { public }
    }
  }
' -f projectId="$PROJECT_ID" > /dev/null
success "Project is now public"

# ── Add custom fields ─────────────────────────────────────────────────────────
add_single_select_field() {
    local name="$1" options_json="$2"
    info "Adding field: $name"
    gh api graphql -f query='
      mutation($projectId: ID!, $name: String!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) {
        createProjectV2Field(input: {
          projectId: $projectId,
          dataType: SINGLE_SELECT,
          name: $name,
          singleSelectOptions: $options
        }) { projectV2Field { ... on ProjectV2SingleSelectField { id name } } }
      }
    ' -f projectId="$PROJECT_ID" -f name="$name" --jq-arg options "$options_json" \
      --raw-field options="$options_json" > /dev/null 2>&1 || warn "Field '$name' may already exist"
}

# Priority field
gh api graphql -f query='
  mutation($projectId: ID!) {
    createProjectV2Field(input: {
      projectId: $projectId,
      dataType: SINGLE_SELECT,
      name: "Priority",
      singleSelectOptions: [
        {name: "P0", color: RED, description: "Critical / Revenue"},
        {name: "P1", color: ORANGE, description: "Core quality"},
        {name: "P2", color: YELLOW, description: "Completeness"},
        {name: "P3", color: GRAY, description: "Nice to have"}
      ]
    }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
  }
' -f projectId="$PROJECT_ID" > /dev/null && success "Added Priority field" || warn "Priority field may exist"

# Effort field
gh api graphql -f query='
  mutation($projectId: ID!) {
    createProjectV2Field(input: {
      projectId: $projectId,
      dataType: SINGLE_SELECT,
      name: "Effort",
      singleSelectOptions: [
        {name: "XS", color: GREEN, description: "~1 day"},
        {name: "S",  color: BLUE,  description: "~1 week"},
        {name: "M",  color: YELLOW,description: "2-4 weeks"},
        {name: "L",  color: ORANGE,description: "1-2 months"},
        {name: "XL", color: RED,   description: "3+ months"}
      ]
    }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
  }
' -f projectId="$PROJECT_ID" > /dev/null && success "Added Effort field" || warn "Effort field may exist"

# Revenue Impact field
gh api graphql -f query='
  mutation($projectId: ID!) {
    createProjectV2Field(input: {
      projectId: $projectId,
      dataType: SINGLE_SELECT,
      name: "Revenue Impact",
      singleSelectOptions: [
        {name: "None",     color: GRAY,   description: ""},
        {name: "Low",      color: BLUE,   description: ""},
        {name: "Medium",   color: YELLOW, description: ""},
        {name: "High",     color: ORANGE, description: ""},
        {name: "Critical", color: RED,    description: "Provenance Plus anchor"}
      ]
    }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
  }
' -f projectId="$PROJECT_ID" > /dev/null && success "Added Revenue Impact field" || warn "Revenue Impact field may exist"

# ── Add issues to project ─────────────────────────────────────────────────────
info "Adding epic issues to project..."
REPO_FULL="Provenance-Emu/Provenance"

EPIC_ISSUES=(659 2483 2482 2505 2510 2540 2541 2543 2544 2545 2575 2631 2649 2658 2659 2690 2691 2696 2705 2716 2723 2725 2726 2727 2738 2746 2747 2748 2751 2752 2758 2767 2792 2800 2816 2822 2862 2868 2880)

added=0
failed=0
for issue_num in "${EPIC_ISSUES[@]}"; do
    # Get issue node ID
    node_id=$(gh api "repos/$REPO_FULL/issues/$issue_num" --jq '.node_id' 2>/dev/null || echo "")
    if [[ -z "$node_id" ]]; then
        warn "Issue #$issue_num not found — skipping"
        failed=$((failed + 1))
        continue
    fi

    # Add to project
    gh api graphql -f query='
      mutation($projectId: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
          item { id }
        }
      }
    ' -f projectId="$PROJECT_ID" -f contentId="$node_id" > /dev/null 2>&1 \
        && added=$((added + 1)) \
        || { warn "Failed to add issue #$issue_num"; failed=$((failed + 1)); }
done

success "Added $added issues ($failed failed)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Provenance Roadmap project created!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo "  Project URL:    $PROJECT_URL"
echo "  Project number: $PROJECT_NUM"
echo ""
echo "  Next steps:"
echo "  1. Update PROJECT_NUMBER in .github/workflows/update-project-status.yml to $PROJECT_NUM"
echo "  2. Pin the project on the repo page"
echo "  3. Add project URL to README"
echo ""
