<!-- clone-me:begin -->
## Commit Style

- Use gitmoji for all commits: ✨ feat, 🐛 fix, ♻️ refactor, 📝 docs, 🔧 config, 🧪 test, 🐳 docker, 🚀 deploy, 🤖 chore/automation
- Conventional scope where meaningful: `✨ feat(auth): add OAuth flow`
- Imperative mood, present tense
- Co-Author line for Claude commits: `Co-Authored-By: Claude <noreply@anthropic.com>`

## Testing

- Every PR must include unit and/or integration tests for new or changed code
- Integration tests hit real services — no mocking internals
- Test structure mirrors source: `test/models/`, `test/services/`, `test/integration/`, `Tests/`, `spec/`, etc.
- Coverage over cleverness: boring tests that clearly describe intent

## Code Quality

- DRY: extract shared logic, no copy-paste across files
- Clean Code: small methods, single responsibility, descriptive names
- Delete unused code; don't comment it out
- No magic numbers or unexplained constants — name everything
- Prefer explicit over implicit

## Documentation

- Document all protocols, endpoints, network communication, and MCP tool contracts
- Include ASCII architecture diagrams for new systems
- Explain *why* decisions were made, not just what the code does
- Every MCP tool, API endpoint, and background job should have a doc comment

## Claude Autonomy

- Read files, list dirs, run tests, create branches, make network calls — no confirmation needed
- Only prompt for: force-push, branch deletion, DB drops, external messaging, merging to main
- Prefer `request_approval` (via robot-fleet MCP) for irreversible destructive actions on fleet-managed repos

## Workflow Tools

- Code reviews: use `/pr-review-toolkit:review-pr` skill
- Dev work (features, bug fixes, refactors): use `/fx-dev:dev` skill
- Required plugins: `fx-dev@fx-cc`, `pr-review-toolkit@claude-plugins-official`
- Install if missing: `claude plugin install fx-dev@fx-cc --scope user`

## Ruby Version Management

- Use RVM (not rbenv) for Ruby version management
- Switch versions with `rvm use ruby-x.y.z`
- RVM wrapper paths: `~/.rvm/wrappers/ruby-x.y.z/bundle exec ...`
<!-- clone-me:end -->
