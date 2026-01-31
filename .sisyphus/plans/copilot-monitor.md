# Work Plan: GitHub Copilot Monitor (macOS)

## Context

### Original Request
A macOS Menu Bar app to verify and display real-time GitHub Copilot Premium request usage (%) and additional budget usage.

### Technical Strategy
- **Platform**: Native macOS (Swift / SwiftUI).
- **Architecture**: Menu Bar App (`NSStatusItem`).
- **Data Source**: Reverse-engineered internal GitHub API.
  - Endpoint: `/settings/billing/copilot_usage_card?customer_id={id}&period=3`
  - ID Retrieval: Parsed from `script[data-target="react-app.embeddedData"]` on billing page.
  - Auth: `WKWebView` (Shared cookies).
- **Refresh Rate**: 30 minutes (Hardcoded).

---

## Work Objectives

### Core Objective
Build a lightweight, secure macOS Menu Bar app that scrapes GitHub Copilot usage via an internal API and displays it in real-time.

### Concrete Deliverables
- **Xcode Project**: `CopilotMonitor.xcodeproj` (SwiftUI App Lifecycle).
- **Menu Bar UI**: `NSStatusItem` with percentage text and dropdown menu.
- **Auth Handler**: `AuthManager` using `WKWebView` to manage GitHub session.
- **Data Fetcher**: `UsageFetcher` to execute JS injection and retrieve JSON.
- **Settings**: Refresh interval (fixed), Launch at Login.

### Definition of Done
- [x] App launches and resides in Menu Bar.
- [x] "Sign In" opens a login window; successful login closes it automatically.
- [x] Menu bar shows usage percentage (e.g., "42%").
- [x] Dropdown shows precise used/limit numbers (e.g., "629 / 1500").
- [x] Manual refresh works.
- [x] App persists state across restarts.

### Must Have
- **Secure Auth**: `WKWebView` handles cookies. No manual cookie handling code.
- **Polling Limits**: Minimum 10 minutes to prevent rate limiting.
- **Error Handling**: "Stale" state indication on network fail.

---

## Settings & Defaults
- **Refresh Interval**: Hardcoded to **30 minutes** (1800s) for MVP.
- **Stale Threshold**: `#if DEBUG` 60 seconds, `#else` 3600 seconds.
- **Launch at Login**: Implemented via `SMAppService.mainApp` (macOS 13+). Managed via "Launch at Login" menu item (toggle).
- **Mock Data**:
  - Condition: Only used if `#if DEBUG` is true AND fetch fails.
  - Content: Hardcoded "Reverse Engineered API Response" JSON.

## State Machine & UI Priority
1. **Fetching**: Show "..." or spinner.
2. **Success**:
   - Update `UserDefaults` cache.
   - Show live percentage (e.g., "42%").
   - Dropdown: "Used: 629 / 1500".
3. **Failure (Network/JS Error)**:
   - Check `UserDefaults` cache.
   - **If Cache Exists**:
     - Show cached percentage.
     - Append " (Old)" to Menu Bar text if `timeSince > staleThreshold`.
     - Dropdown: "Used: ... (Cached)".
   - **If No Cache**:
     - Show "Err".
     - Dropdown: "Error: [Message]".

## Architecture & Data Flow

### Component Responsibilities
- **AuthManager (Singleton)**: Owns `WKWebView`. Responsible for loading pages and detecting login state.
- **UsageFetcher (Stateless)**: Accepts `WKWebView` and performs JS injection to retrieve data.
- **StatusBarController (UI)**: Observes notifications, updates UI, and manages the Timer.

### Refresh Sequence (The "Loop")
1. **Trigger**: Timer (every 30m) OR User clicks "Refresh".
2. **Action**: Call `AuthManager.shared.loadBillingPage()`.
3. **Auth Check**:
   - If redirected to `/login`: `AuthManager` posts `SessionExpired`.
   - If loaded `/settings/billing`: `AuthManager` posts `BillingPageLoaded`.
4. **Login Window Handling**:
   - `AppDelegate` observes `BillingPageLoaded`.
   - If `LoginWindow` is currently open, `AppDelegate` closes it.
5. **Data Fetch**:
   - `StatusBarController` observes `BillingPageLoaded`.
   - Calls `UsageFetcher.fetch(from: AuthManager.shared.webView)`.
6. **Update UI**:
   - Success: Update Menu Bar text, save to `UserDefaults`.
   - Failure: Update Menu Bar with "Err", keep old data in dropdown (marked Stale).

## Evidence & References (Internal)

### 1. Reverse Engineered API Response (Reference)
*Captured from Chrome DevTools on 2026-01-18*
```json
{
  "netBilledAmount": 0.0,
  "netQuantity": 0.0,
  "discountQuantity": 629.28,
  "userPremiumRequestEntitlement": 1500,
  "filteredUserPremiumRequestEntitlement": 0
}
```

### 2. DOM Extraction Source (Reference)
*Captured from Chrome DevTools on 2026-01-18*
```html
<script type="application/json" data-target="react-app.embeddedData">
{"payload":{"customer":{"billingTarget":1,"customerId":6911066,"customerType":"User" ... }}}
</script>
```

### 3. NSStatusItem Pattern (Reference)
```swift
// Use this pattern in StatusBarController
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "Loading..."
let menu = NSMenu()
// Action Handling
menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q"))
statusItem.menu = menu

@objc func quitClicked() {
    NSApp.terminate(nil)
}
```

### 4. WebView Representable Pattern (Reference)
```swift
struct LoginView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { return webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
```

## Guardrails & Security
- **Domain Whitelist**: `*.github.com`, `*.githubassets.com`, `*.githubusercontent.com`. Block all others in `decidePolicyFor`.
- **WebView Sharing**: `AuthManager.shared.webView` is the SINGLE instance used for both background fetching and the login window. This ensures cookies are shared 100%.
- **JS Injection**: Use `callAsyncJavaScript` for robust Promise handling.

...

- [x] 1. **Project Setup & Architecture**
  - **What to do**:
    - Create new macOS App (SwiftUI) named `CopilotMonitor` in `projects/copilot-usage-monitor`.
    - Create `App/AppDelegate.swift` conforming to `NSObject, NSApplicationDelegate`.
      - Add property: `var loginWindow: NSWindow?`.
    - In `CopilotMonitorApp.swift`, use `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`.
...

- [x] 2. **Implement AuthManager (Hidden WebView)**
...
    - `showLoginWindow()` (in `AppDelegate` via notification): 
      - If `loginWindow == nil`, create `NSWindow` with content `LoginView(webView: AuthManager.shared.webView)`.
      - `loginWindow?.makeKeyAndOrderFront(nil)`.
    - `hideLoginWindow()` (in `AppDelegate` via notification):
      - `loginWindow?.close()`.
      - `loginWindow = nil`.
...

- [x] 4. **Build Menu Bar UI (NSMenu)**
  - **What to do**:
    - In `StatusBarController`, use `NSMenu`.
    - Implement `@objc` action handlers:
      - `refreshClicked()`: Calls `UsageFetcher.fetchUsage`.
      - `openBillingClicked()`: Calls `NSWorkspace.shared.open(...)`.
      - `quitClicked()`: Calls `NSApp.terminate`.
    - Create `menu = NSMenu()`.
    - Item 1: `usageItem` (Title: "Used: ...", action: nil).
...
    - Item 3: "Refresh" (Target: `self`, Action: `#selector(refreshClicked)`).
    - Item 4: "Open Billing" (Target: `self`, Action: `#selector(openBillingClicked)`).
    - Item 5: "Quit" (Target: `self`, Action: `#selector(quitClicked)`).
...


- [x] 5. **Polishing & Persistence**
  - **What to do**:
    - **Persistence**: Define `CachedUsage: Codable { let usage: CopilotUsage; let timestamp: Date }`. Save to `UserDefaults` key `"copilot.usage.cache"`.
    - **Stale Logic**: Use `#if DEBUG` 60.0 else 3600.0 for threshold.
    - **Launch at Login**:
      - Add `LaunchAtLogin` menu item.
      - Action: Check `SMAppService.mainApp.status`. If `.enabled`, calling `.unregister()`, else `.register()`.
    - **Wiring**:
      - `AppDelegate` listens for `BillingPageLoaded` -> Closes Login Window (if open).
      - On notification, call `UsageFetcher.fetchUsage`.
      - On success, update `StatusBarController` and save cache.
      - On failure, load cache and update `StatusBarController` with stale state.
      - `AppDelegate` listens for `SessionExpired` -> Show Login Window.
    - **Timer**: `Timer.scheduledTimer` calls `AuthManager.loadBillingPage` every 30m.
  - **Verification**:
    - Toggle "Launch at Login" -> Go to System Settings > General > Login Items -> Verify entry appears/disappears.
    - Restart app -> Data persists.
    - Wait 1 min (with debug 60s stale threshold) -> Verify "Stale" indicator.
    - Expire session (logout in Safari) -> App should prompt re-login on next fetch.
