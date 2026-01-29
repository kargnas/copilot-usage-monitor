## Language
- All of comments in code base, commit message, PR content and title should be written in English.
  - If you find any Korean text, please translate it to English.
- **UI Language**: All user-facing text in the app MUST be in English.

## UI Styling Rules
- **No colors for text emphasis**: Do NOT use `NSColor` attributes like `.foregroundColor` for menu items or labels.
- **Use instead**:
  - **Bold**: `NSFont.boldSystemFont(ofSize:)` for important text
  - **Underline**: `.underlineStyle: NSUnderlineStyle.single.rawValue` for critical warnings
  - **SF Symbols**: Use `NSImage(systemSymbolName:accessibilityDescription:)` for menu item icons
- **Do NOT use**:
  - **Emoji**: Never use emoji for menu item icons. Always use SF Symbols instead.
- **Exception**: Progress bars and status indicators can use color (green/yellow/orange/red).

## Requirements
- Get the data from API only, not from DOM.
- Get useful session information (cookie, bearer and etc) from DOM/HTML if needed.
- Login should be webview and ask to the user to login.

## Reference
- Copilot Usage (HTML)
  - https://github.com/settings/billing/premium_requests_usage

## Instruction
- Always compile and run again after each change, and then ask to the user to see it. (Kill the existing process before running)

## Release Policy
- **Workflow**: STRICTLY follow `docs/RELEASE_WORKFLOW.md` for versioning, building, signing, and notarizing.
- **Signing**: All DMGs distributed via GitHub Releases **MUST** be signed with Developer ID and **NOTARIZED** to pass macOS Gatekeeper.
- **Documentation**: Update `README.md` and screenshots if UI changes significantly before release.

<!-- opencode:reflection:start -->
### Error Handling & API Fallbacks
- **NSNumber Type Handling**: API responses may return `NSNumber` instead of `Int` or `Double`
  - Always check for `NSNumber` type when parsing numeric values from API responses
  - Pattern: `value as? NSNumber` → `doubleValue`/`intValue`
  - Example failure: Cost showing wrong value due to missing NSNumber handling
- **Menu Bar App (LSUIElement) Special Requirements**:
  - UI Display: Must call `NSApp.activate(ignoringOtherApps: true)` before showing update dialogs
  - Target Assignment: Menu item targets must be explicitly set to `NSApp.delegate` (not `self`)
  - Window Management: Close blank Settings windows on app launch
- **Swift Concurrency & Actor Isolation**:
  - Task Capture: Always use `[weak self]` in Task blocks to avoid retain cycles
  - MainActor: Use `@MainActor [weak self]` pattern when updating UI from async contexts
  - Pre-compute Values: Cache values like `refreshInterval.title` before Task to avoid actor isolation issues
- **Usage Calculation Completeness**:
  - Total Requests: Always sum both `includedRequests` AND `billedRequests` for accurate predictions
  - Prediction Algorithms: Use `totalRequests` (not just `included`) for weighted average calculations
  - UI Display: Show total requests in daily usage breakdown, not just included
- **DMG Packaging Cleanliness**:
  - Staging Directory: Create clean staging dir containing ONLY app bundle and Applications symlink
  - Exclude Files: Prevent `Packaging.log`, `DistributionSummary.plist`, and other Xcode artifacts from DMG
  - Pattern: `mkdir -p staging; cp -R app.app staging/; ln -s /Applications staging/`
- **DerivedData Path Handling**:
  - Wildcard Warning: Path `~/Library/Developer/Xcode/DerivedData/CopilotMonitor-*/Build/Products/Debug/CopilotMonitor.app` may break if multiple DerivedData directories exist
  - Solution: Use `xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR` to get exact path, or open using `open` which finds the latest build
<!-- opencode:reflection:end -->
