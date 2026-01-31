# Unified AI Usage Monitor (CopilotMonitor Pro)

## TL;DR

> **Quick Summary**: Transform CopilotMonitor from single-provider Copilot tracker into multi-provider AI usage monitor with pay-as-you-go cost tracking and quota-based alert system.
> 
> **Deliverables**:
> - Protocol-based provider architecture supporting 4 providers (MVP)
> - Unified menu bar showing total overage cost + quota alerts
> - Dropdown with Pay-as-you-go and Quota sections
> - Unit tests for models and services
> 
> **Estimated Effort**: Large (15-20 tasks)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (Protocol) → Task 3-6 (Providers) → Task 8 (Menu Bar)

---

## Context

### Original Request
Transform CopilotMonitor into a unified AI usage monitor that tracks multiple AI providers, showing overage costs for pay-as-you-go providers and remaining % alerts for quota-based providers.

### Interview Summary
**Key Discussions**:
- Provider classification: Pay-as-you-go (Copilot) vs Quota-based (Claude, Codex, Gemini CLI)
- Menu bar design: Total overage cost + vendor icon alerts when <20% remaining
- Dropdown: Simple 2-section layout (Pay-as-you-go + Quota)
- Settings: In-menu (no separate window)
- Cookie extraction: Swift native implementation

**Research Findings**:
- All API endpoints documented in `docs/AI_USAGE_API_REFERENCE.md`
- Existing `StatusBarController.swift` is 1267 lines - needs decomposition
- Provider icons already exist in Assets.xcassets
- OAuth tokens available in OpenCode auth files

### Metis Review
**Identified Gaps** (addressed):
- MVP scope unclear → Locked to 4 providers (Copilot, Claude, Codex, Gemini CLI)
- Error handling undefined → Cache last value + staleness indicator
- Token refresh flow → Auto-refresh for Gemini, others use existing tokens
- Settings scope creep → Only existing settings + provider enable/disable

---

## Work Objectives

### Core Objective
Create protocol-based multi-provider architecture that displays aggregated overage costs and quota alerts in the macOS menu bar.

### Concrete Deliverables
- `ProviderProtocol.swift` - Provider interface definition
- `ProviderUsage.swift` - Unified usage data model
- `ClaudeProvider.swift`, `CodexProvider.swift`, `GeminiCLIProvider.swift` - Provider implementations
- `ProviderManager.swift` - Coordinator for multiple providers
- `MultiProviderStatusBarIconView.swift` - New menu bar view
- Updated `StatusBarController.swift` - Refactored for multi-provider
- `CopilotMonitorTests/` - Unit tests for models and providers

### Definition of Done
- [x] App builds without errors: `xcodebuild -scheme CopilotMonitor build`
- [x] App launches and shows menu bar icon
- [x] Dropdown shows both sections (Pay-as-you-go + Quota)
- [x] At least 2 providers fetch data successfully
- [x] Unit tests pass: `xcodebuild test -scheme CopilotMonitor`

### Must Have
- Protocol-based provider architecture
- 4 providers: Copilot (existing), Claude, Codex, Gemini CLI
- Total overage cost in menu bar
- Quota alert icons (<20% remaining)
- 2-section dropdown menu
- Error handling with cached fallback

### Must NOT Have (Guardrails)
- ❌ Antigravity Local provider (Phase 2 - complex process inspection)
- ❌ OpenRouter provider (Phase 2 - API key storage unclear)
- ❌ OpenCode provider (Phase 2 - CLI dependency)
- ❌ Historical charts or graphs
- ❌ Multi-account support per provider
- ❌ Separate Settings window
- ❌ Per-provider refresh intervals
- ❌ Emoji in menu items (use SF Symbols or bundled icons)
- ❌ Color for text emphasis (use bold/underline per AGENTS.md)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (need to set up XCTest target)
- **User wants tests**: YES (Unit tests for models)
- **Framework**: XCTest (native)

### Test Setup Task
- [x] 0. Setup Test Infrastructure
  - Create: `CopilotMonitorTests` target in Xcode project
  - Config: Link to main target for model access
  - Verify: `xcodebuild test -scheme CopilotMonitor` runs
  - Example: Create `ProviderUsageTests.swift`
  - Verify: At least 1 test passes

### Automated Verification Approach

**For API Providers** (using Bash curl):
```bash
# Claude API check:
ACCESS=$(jq -r '.anthropic.access' ~/.local/share/opencode/auth.json)
curl -s "https://api.anthropic.com/api/oauth/usage" \
  -H "Authorization: Bearer $ACCESS" \
  -H "anthropic-beta: oauth-2025-04-20" | jq '.seven_day.utilization'
# Assert: Returns number 0-100
```

**For Model Parsing** (using XCTest):
```swift
func testClaudeUsageParsing() {
    let json = """
    {"seven_day": {"utilization": 42.5, "resets_at": "2026-02-01T00:00:00Z"}}
    """
    let usage = try! JSONDecoder().decode(ClaudeUsageResponse.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(usage.seven_day.utilization, 42.5)
}
```

**For Menu Bar UI** (manual QA):
- App runs without crash
- Menu bar icon visible
- Dropdown opens on click
- Sections display correctly

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Create ProviderProtocol and ProviderUsage models [no deps]
├── Task 2: Setup XCTest infrastructure [no deps]
└── Task 7: Create TokenManager for auth file reading [no deps]

Wave 2 (After Wave 1):
├── Task 3: Implement ClaudeProvider [depends: 1, 7]
├── Task 4: Implement CodexProvider [depends: 1, 7]
├── Task 5: Implement GeminiCLIProvider [depends: 1, 7]
├── Task 6: Refactor CopilotProvider from existing code [depends: 1]
└── Task 8: Create ProviderManager coordinator [depends: 1]

Wave 3 (After Wave 2):
├── Task 9: Create MultiProviderStatusBarIconView [depends: 3-6, 8]
├── Task 10: Update dropdown menu sections [depends: 8, 9]
├── Task 11: Add provider enable/disable settings [depends: 8]
└── Task 12: Integration testing and polish [depends: 9, 10, 11]

Critical Path: Task 1 → Task 3-6 → Task 8 → Task 9 → Task 12
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4, 5, 6, 8 | 2, 7 |
| 2 | None | 12 | 1, 7 |
| 3 | 1, 7 | 9 | 4, 5, 6, 8 |
| 4 | 1, 7 | 9 | 3, 5, 6, 8 |
| 5 | 1, 7 | 9 | 3, 4, 6, 8 |
| 6 | 1 | 9 | 3, 4, 5, 8 |
| 7 | None | 3, 4, 5 | 1, 2 |
| 8 | 1 | 9, 10, 11 | 3, 4, 5, 6 |
| 9 | 3-6, 8 | 12 | 10, 11 |
| 10 | 8, 9 | 12 | 11 |
| 11 | 8 | 12 | 9, 10 |
| 12 | 9, 10, 11 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 2, 7 | 3 parallel sisyphus-junior agents |
| 2 | 3, 4, 5, 6, 8 | 5 parallel agents (all independent after Wave 1) |
| 3 | 9, 10, 11 | 3 parallel agents |
| Final | 12 | 1 agent for integration |

---

## TODOs

### Wave 1: Foundation

- [x] 1. Create ProviderProtocol and ProviderUsage models

  **What to do**:
  - Create `Models/ProviderProtocol.swift` with async fetch interface
  - Create `Models/ProviderUsage.swift` with variants for pay-as-you-go vs quota
  - Define `ProviderType` enum (`.payAsYouGo`, `.quotaBased`)
  - Define `ProviderIdentifier` enum (`.copilot`, `.claude`, `.codex`, `.geminiCLI`)

  **Must NOT do**:
  - Do NOT add providers for Phase 2 (Antigravity Local, OpenRouter, OpenCode)
  - Do NOT create separate usage models per provider

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Model definitions only, no complex logic
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits after task completion
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: No UI work in this task

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 7)
  - **Blocks**: Tasks 3, 4, 5, 6, 8
  - **Blocked By**: None

  **References**:
  - `CopilotMonitor/CopilotMonitor/Models/CopilotUsage.swift:3-33` - Existing model pattern (Codable, computed properties)
  - `docs/AI_USAGE_API_REFERENCE.md:26-34` - Claude response shape
  - `docs/AI_USAGE_API_REFERENCE.md:56-79` - Codex response shape
  - `docs/AI_USAGE_API_REFERENCE.md:96-117` - Copilot response shape

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Models/ProviderProtocol.swift`
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Models/ProviderUsage.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build 2>&1 | grep -E "(BUILD SUCCEEDED|error:)"`
  - [ ] Protocol defines: `func fetch() async throws -> ProviderUsage`

  **Commit**: YES
  - Message: `feat(models): add ProviderProtocol and ProviderUsage for multi-provider support`
  - Files: `Models/ProviderProtocol.swift`, `Models/ProviderUsage.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 2. Setup XCTest infrastructure

  **What to do**:
  - Add `CopilotMonitorTests` target to Xcode project
  - Create `CopilotMonitorTests/ProviderUsageTests.swift` with basic test
  - Create `CopilotMonitorTests/Fixtures/` directory for mock JSON responses
  - Add mock JSON files for Claude, Codex, Copilot, Gemini responses

  **Must NOT do**:
  - Do NOT write UI tests (manual QA for UI)
  - Do NOT require real API calls in tests

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Project configuration, not complex coding
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 7)
  - **Blocks**: Task 12 (integration testing)
  - **Blocked By**: None

  **References**:
  - `CopilotMonitor/CopilotMonitor.xcodeproj/project.pbxproj` - Project file to modify
  - `docs/AI_USAGE_API_REFERENCE.md:26-34` - Claude response for fixture
  - `docs/AI_USAGE_API_REFERENCE.md:56-79` - Codex response for fixture
  - Apple XCTest documentation: Basic test structure

  **Acceptance Criteria**:
  - [ ] Test target exists in project
  - [ ] Test runs: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite|passed|failed)"`
  - [ ] At least 1 test passes
  - [ ] Fixtures directory exists: `ls CopilotMonitorTests/Fixtures/`

  **Commit**: YES
  - Message: `test(setup): add XCTest infrastructure with mock fixtures`
  - Files: `CopilotMonitorTests/`, `project.pbxproj`
  - Pre-commit: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`

---

- [x] 7. Create TokenManager for auth file reading

  **What to do**:
  - Create `Services/TokenManager.swift` singleton
  - Implement reading from `~/.local/share/opencode/auth.json`
  - Implement reading from `~/.config/opencode/antigravity-accounts.json`
  - Define structs for JSON parsing (`OpenCodeAuth`, `AntigravityAccounts`)
  - Implement OAuth token refresh for Gemini (using refresh_token)

  **Must NOT do**:
  - Do NOT store tokens in UserDefaults
  - Do NOT implement browser cookie extraction (separate task)
  - Do NOT cache tokens longer than necessary

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: File I/O and JSON parsing, straightforward
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 3, 4, 5
  - **Blocked By**: None

  **References**:
  - `docs/AI_USAGE_API_REFERENCE.md:232-279` - Token file structures
  - `docs/AI_USAGE_API_REFERENCE.md:136-148` - Gemini OAuth refresh flow
  - `docs/AI_USAGE_API_REFERENCE.md:304-355` - Swift implementation example

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Services/TokenManager.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] Verify in REPL or logs: `TokenManager.shared.claudeToken` returns value if auth.json exists

  **Commit**: YES
  - Message: `feat(services): add TokenManager for OpenCode auth file reading`
  - Files: `Services/TokenManager.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

### Wave 2: Provider Implementations

- [x] 3. Implement ClaudeProvider

  **What to do**:
  - Create `Providers/ClaudeProvider.swift` conforming to `ProviderProtocol`
  - Implement API call to `https://api.anthropic.com/api/oauth/usage`
  - Parse response into `ProviderUsage.quotaBased(remaining: Double, resetAt: Date?)`
  - Handle 401 (token expired) by returning error state
  - Use `TokenManager` for auth token

  **Must NOT do**:
  - Do NOT implement token refresh (Claude tokens are long-lived)
  - Do NOT show both 5h and 7d windows (use 7d as primary)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single API call implementation
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Tasks 1, 7

  **References**:
  - `docs/AI_USAGE_API_REFERENCE.md:14-41` - Claude API endpoint and response
  - `CopilotMonitor/CopilotMonitor/Models/ProviderProtocol.swift` - Protocol to conform to (created in Task 1)
  - `CopilotMonitor/CopilotMonitor/Services/TokenManager.swift` - Token access (created in Task 7)

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Providers/ClaudeProvider.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] Manual API test: `./scripts/query-claude.sh` returns utilization %
  - [ ] Unit test: Parse mock Claude response correctly

  **Commit**: YES
  - Message: `feat(providers): implement ClaudeProvider with quota tracking`
  - Files: `Providers/ClaudeProvider.swift`, `CopilotMonitorTests/ClaudeProviderTests.swift`
  - Pre-commit: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`

---

- [x] 4. Implement CodexProvider

  **What to do**:
  - Create `Providers/CodexProvider.swift` conforming to `ProviderProtocol`
  - Implement API call to `https://chatgpt.com/backend-api/wham/usage`
  - Include `ChatGPT-Account-Id` header from auth file
  - Parse `primary_window.used_percent` into quota remaining
  - Use `TokenManager` for auth token and accountId

  **Must NOT do**:
  - Do NOT show secondary_window (use primary as main metric)
  - Do NOT show credits balance (beyond scope)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single API call implementation
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 5, 6, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Tasks 1, 7

  **References**:
  - `docs/AI_USAGE_API_REFERENCE.md:44-79` - Codex API endpoint and response
  - `CopilotMonitor/CopilotMonitor/Models/ProviderProtocol.swift` - Protocol to conform to
  - `CopilotMonitor/CopilotMonitor/Services/TokenManager.swift` - Token access

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Providers/CodexProvider.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] Manual API test: `./scripts/query-codex.sh` returns used_percent
  - [ ] Unit test: Parse mock Codex response correctly

  **Commit**: YES
  - Message: `feat(providers): implement CodexProvider with quota tracking`
  - Files: `Providers/CodexProvider.swift`, `CopilotMonitorTests/CodexProviderTests.swift`
  - Pre-commit: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`

---

- [x] 5. Implement GeminiCLIProvider

  **What to do**:
  - Create `Providers/GeminiCLIProvider.swift` conforming to `ProviderProtocol`
  - Implement OAuth token refresh using refresh_token from antigravity-accounts.json
  - Call `https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota`
  - Parse `buckets` array, use lowest `remainingFraction` as primary metric
  - Handle multiple model buckets (show aggregate or worst-case)

  **Must NOT do**:
  - Do NOT show per-model breakdown in menu bar (too complex)
  - Do NOT hardcode client_id/secret (already in reference doc, use constants)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: OAuth refresh adds complexity, but still straightforward
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 6, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Tasks 1, 7

  **References**:
  - `docs/AI_USAGE_API_REFERENCE.md:122-159` - Gemini CLI API and OAuth refresh
  - `docs/AI_USAGE_API_REFERENCE.md:219-228` - Antigravity OAuth credentials
  - `CopilotMonitor/CopilotMonitor/Services/TokenManager.swift` - Refresh token access

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Providers/GeminiCLIProvider.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] Manual API test: `./scripts/query-gemini-cli.sh` returns remainingFraction
  - [ ] Unit test: Parse mock Gemini response correctly

  **Commit**: YES
  - Message: `feat(providers): implement GeminiCLIProvider with OAuth refresh`
  - Files: `Providers/GeminiCLIProvider.swift`, `CopilotMonitorTests/GeminiCLIProviderTests.swift`
  - Pre-commit: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`

---

- [x] 6. Refactor CopilotProvider from existing code

  **What to do**:
  - Create `Providers/CopilotProvider.swift` conforming to `ProviderProtocol`
  - Extract fetch logic from `StatusBarController.swift` (lines ~640-900)
  - Keep existing `CopilotUsage` model for backward compatibility
  - Map to `ProviderUsage.payAsYouGo(cost: Double, used: Int, limit: Int)`
  - Keep cached data fallback on error

  **Must NOT do**:
  - Do NOT remove existing StatusBarController logic yet (Task 10)
  - Do NOT break existing functionality
  - Do NOT remove history fetching (keep it separate)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Extraction requires careful reading of existing code
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5, 8)
  - **Blocks**: Task 9
  - **Blocked By**: Task 1

  **References**:
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:640-900` - Existing fetch logic to extract
  - `CopilotMonitor/CopilotMonitor/Models/CopilotUsage.swift:1-39` - Existing model to keep
  - `CopilotMonitor/CopilotMonitor/Services/UsageFetcher.swift:1-121` - Reference (mostly unused, can deprecate)

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Providers/CopilotProvider.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] CopilotProvider.fetch() returns same data as existing implementation
  - [ ] Unit test: Verify cost calculation matches existing logic

  **Commit**: YES
  - Message: `refactor(providers): extract CopilotProvider from StatusBarController`
  - Files: `Providers/CopilotProvider.swift`, `CopilotMonitorTests/CopilotProviderTests.swift`
  - Pre-commit: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`

---

- [x] 8. Create ProviderManager coordinator

  **What to do**:
  - Create `Services/ProviderManager.swift` singleton
  - Manage array of active providers
  - Implement `fetchAll() async -> [ProviderIdentifier: ProviderUsage]`
  - Calculate aggregated overage cost from pay-as-you-go providers
  - Track quota alerts (providers with <20% remaining)
  - Handle errors gracefully (partial results OK)

  **Must NOT do**:
  - Do NOT implement per-provider refresh intervals (global only)
  - Do NOT block on slow providers (use timeout)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Coordination logic, async handling
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5, 6)
  - **Blocks**: Tasks 9, 10, 11
  - **Blocked By**: Task 1

  **References**:
  - `CopilotMonitor/CopilotMonitor/Models/ProviderProtocol.swift` - Protocol to manage
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:7` - Logger pattern
  - Swift Concurrency: TaskGroup for parallel fetching

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Services/ProviderManager.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] fetchAll() returns results for all registered providers
  - [ ] Aggregated cost calculation correct

  **Commit**: YES
  - Message: `feat(services): add ProviderManager to coordinate multi-provider fetching`
  - Files: `Services/ProviderManager.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

### Wave 3: UI Integration

- [x] 9. Create MultiProviderStatusBarIconView

  **What to do**:
  - Create new `Views/MultiProviderStatusBarIconView.swift`
  - Display format: `[$XXX 🔴ClaudeIcon 5% 🔴GeminiIcon 8%]`
  - Dynamic width calculation for variable alerts
  - Use existing provider icons from Assets.xcassets
  - Alert threshold: 20% remaining (configurable later)
  - Tint icons red for alert state

  **Must NOT do**:
  - Do NOT use emoji for provider icons (use bundled imagesets)
  - Do NOT use color for text (use bold for emphasis)
  - Do NOT show all providers in menu bar (only alerts + total cost)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Custom NSView drawing, icon rendering
  - **Skills**: [`frontend-ui-ux`, `git-master`]
    - `frontend-ui-ux`: Menu bar icon design
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - `frontend-design`: Not web frontend

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 10, 11)
  - **Blocks**: Task 12
  - **Blocked By**: Tasks 3, 4, 5, 6, 8

  **References**:
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:58-227` - Existing StatusBarIconView pattern
  - `CopilotMonitor/CopilotMonitor/Assets.xcassets/ClaudeIcon.imageset/` - Provider icon assets
  - `AGENTS.md` - UI styling rules (no colors for text, use SF Symbols)

  **Acceptance Criteria**:
  - [ ] File exists: `CopilotMonitor/CopilotMonitor/Views/MultiProviderStatusBarIconView.swift`
  - [ ] Build succeeds: `xcodebuild -scheme CopilotMonitor build`
  - [ ] Manual QA: Menu bar shows cost + alert icons correctly
  - [ ] Icons render with correct tint for alert state

  **Commit**: YES
  - Message: `feat(ui): add MultiProviderStatusBarIconView for unified display`
  - Files: `Views/MultiProviderStatusBarIconView.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 10. Update dropdown menu sections

  **What to do**:
  - Modify `StatusBarController` to use ProviderManager
  - Create "Pay-as-you-go" section with cost per provider
  - Create "Quota Status" section with progress bars
  - Keep existing Settings section (refresh interval, prediction, launch at login)
  - Replace old single-provider menu with new sections

  **Must NOT do**:
  - Do NOT remove history submenu (keep for Copilot)
  - Do NOT add provider-specific settings (MVP)
  - Do NOT create separate settings window

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Menu UI work
  - **Skills**: [`frontend-ui-ux`, `git-master`]
    - `frontend-ui-ux`: Menu design
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 11)
  - **Blocks**: Task 12
  - **Blocked By**: Tasks 8, 9

  **References**:
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:340-600` - Existing menu building
  - Draft: `.sisyphus/drafts/unified-ai-monitor.md` - Dropdown structure design

  **Acceptance Criteria**:
  - [ ] Dropdown has "Pay-as-you-go" header with provider items
  - [ ] Dropdown has "Quota Status" header with provider items
  - [ ] Settings section preserved
  - [ ] Manual QA: Menu opens and displays all sections

  **Commit**: YES
  - Message: `feat(ui): update dropdown menu with multi-provider sections`
  - Files: `App/StatusBarController.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 11. Add provider enable/disable settings

  **What to do**:
  - Add "Enabled Providers" submenu to Settings section
  - Store enabled state in UserDefaults per provider
  - Default all providers to enabled
  - ProviderManager respects enabled state

  **Must NOT do**:
  - Do NOT create separate Settings window
  - Do NOT add per-provider refresh intervals

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple UserDefaults + menu toggle
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Simple menu items, not complex UI

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 10)
  - **Blocks**: Task 12
  - **Blocked By**: Task 8

  **References**:
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:500-600` - Existing settings menu pattern
  - UserDefaults: Standard storage pattern

  **Acceptance Criteria**:
  - [ ] "Enabled Providers" submenu appears in Settings
  - [ ] Toggling provider persists across app restart
  - [ ] Disabled providers not fetched or displayed

  **Commit**: YES
  - Message: `feat(settings): add provider enable/disable toggles`
  - Files: `App/StatusBarController.swift`, `Services/ProviderManager.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 12. Integration testing and polish

  **What to do**:
  - Test all 4 providers together
  - Verify menu bar updates correctly
  - Verify dropdown displays all data
  - Fix any integration bugs
  - Update README with new features
  - Run full test suite

  **Must NOT do**:
  - Do NOT add new features
  - Do NOT change architecture

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Testing and documentation
  - **Skills**: [`git-master`]
    - `git-master`: For atomic commits
  - **Skills Evaluated but Omitted**:
    - None relevant

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: None (final task)
  - **Blocks**: None
  - **Blocked By**: Tasks 9, 10, 11

  **References**:
  - All previous task outputs
  - `README.md` - Documentation to update

  **Acceptance Criteria**:
  - [ ] All tests pass: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`
  - [ ] App runs without crash for 5 minutes
  - [ ] All 4 providers fetch and display data
  - [ ] README updated with multi-provider features
  - [ ] No compiler warnings

  **Commit**: YES
  - Message: `docs: update README for multi-provider support and polish`
  - Files: `README.md`, any bug fixes
  - Pre-commit: `xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS'`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(models): add ProviderProtocol and ProviderUsage` | Models/*.swift | build |
| 2 | `test(setup): add XCTest infrastructure` | Tests/, project.pbxproj | test |
| 7 | `feat(services): add TokenManager` | Services/TokenManager.swift | build |
| 3 | `feat(providers): implement ClaudeProvider` | Providers/ClaudeProvider.swift | test |
| 4 | `feat(providers): implement CodexProvider` | Providers/CodexProvider.swift | test |
| 5 | `feat(providers): implement GeminiCLIProvider` | Providers/GeminiCLIProvider.swift | test |
| 6 | `refactor(providers): extract CopilotProvider` | Providers/CopilotProvider.swift | test |
| 8 | `feat(services): add ProviderManager` | Services/ProviderManager.swift | build |
| 9 | `feat(ui): add MultiProviderStatusBarIconView` | Views/*.swift | build |
| 10 | `feat(ui): update dropdown menu sections` | StatusBarController.swift | build |
| 11 | `feat(settings): add provider toggles` | StatusBarController.swift | build |
| 12 | `docs: update README for multi-provider` | README.md | test |

---

## Success Criteria

### Verification Commands
```bash
# Build
xcodebuild -scheme CopilotMonitor build 2>&1 | grep "BUILD SUCCEEDED"

# Test
xcodebuild test -scheme CopilotMonitor -destination 'platform=macOS' 2>&1 | grep -E "Test Suite.*passed"

# API verification (manual)
./scripts/query-claude.sh    # Returns utilization %
./scripts/query-codex.sh     # Returns used_percent
./scripts/query-copilot.sh   # Returns remaining
./scripts/query-gemini-cli.sh # Returns remainingFraction
```

### Final Checklist
- [x] All "Must Have" features implemented
- [x] All "Must NOT Have" guardrails respected
- [x] All tests pass
- [x] App runs without crash
- [x] Menu bar displays cost + alerts
- [x] Dropdown shows both sections
- [x] 4 providers working (Copilot, Claude, Codex, Gemini CLI)
