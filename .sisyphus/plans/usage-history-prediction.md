# Usage History & Monthly Prediction Feature

## Context

### Original Request
사용자가 새로운 API 엔드포인트(`/settings/billing/copilot_usage_table`)를 발견함. 이 API는 날짜별 사용량 데이터를 제공하며, 이를 활용하여:
1. 장기적인 사용량 히스토리 표시
2. 이번달 총 사용량 예측(Prediction) 기능 구현

### Interview Summary
**Key Discussions**:
- API 구조: `period=3`(이번달 일별), `period=5`(지난달 일별)
- 예측 알고리즘: 최근 7일 가중치 + 요일별 패턴 고려
- UI 방식: 메뉴 확장 (서브메뉴)

**Research Findings**:
- API 응답에서 `cells[1].value`가 "908.59" 형태의 문자열 (소수점 포함)
- 모델별 breakdown 데이터도 `subtable`로 제공됨
- 기존 코드에서 `CopilotUsage` 모델이 중복 정의되어 있음 (정리 필요)

### Metis Review
**Identified Gaps** (addressed):
1. 소수점 데이터 처리 → `Double` 타입으로 저장
2. 타임존 처리 → UTC 기준, 로컬 변환은 표시 시에만
3. 주말 0 사용량 처리 → 알고리즘에서 0도 유효 데이터로 처리
4. 데이터 부족 시 예측 → "예측 정확도 낮음" 표시
5. API 호출 타이밍 → 별도 타이머, 5분 간격 최소

---

## Work Objectives

### Core Objective
Copilot Monitor 앱에 일별 사용량 히스토리와 월말 예측 기능을 추가하여, 사용자가 장기적인 사용 패턴을 파악하고 비용을 예측할 수 있게 함.

### Concrete Deliverables
1. `Models/UsageHistory.swift` - 일별 사용량 데이터 모델
2. `Services/UsagePredictor.swift` - 예측 알고리즘 클래스
3. `App/StatusBarController.swift` 수정 - 새 API 호출, 서브메뉴 UI, 캐싱 통합

> **Note**: 서브메뉴 UI는 별도 파일 없이 `StatusBarController.swift` 내에서 `NSMenuItem` + `submenu`로 구현 (기존 Auto Refresh 서브메뉴 패턴 따름)

### Definition of Done
- [x] 메뉴에서 최근 7일 일별 사용량 확인 가능
- [x] 월말 예상 총 사용량 표시됨
- [x] 예상 추가 비용 (limit 초과 시) 표시됨
- [x] 데이터 < 7일 시 "예측 정확도 낮음" 표시
- [x] 네트워크 에러 시 캐시된 데이터 표시
- [x] 앱 빌드 성공: `xcodebuild -scheme CopilotMonitor build`

### Must Have
- 일별 사용량 데이터 파싱 (copilot_usage_table API)
- 최근 7일 가중치 기반 예측 알고리즘
- 요일별 패턴 고려 (주중/주말 차이)
- 서브메뉴 형태의 UI
- 히스토리 데이터 캐싱 (UserDefaults)

### Must NOT Have (Guardrails)
- 기존 `copilot_usage_card` API 호출 코드 수정 금지
- `StatusBarIconView` 렌더링 로직 변경 금지
- 외부 차트 라이브러리 추가 금지
- Main menu에 예측값 직접 추가 금지 (서브메뉴로만)
- Auto-refresh 타이머에 history fetch 포함 금지
- Model별 breakdown UI 구현 금지 (후속 버전에서)
- 월별 비교 차트/그래프 금지

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (Xcode 프로젝트, 별도 테스트 타겟 없음)
- **User wants tests**: Manual-only
- **Framework**: none

### Manual QA Procedures

각 TODO에 상세한 수동 검증 절차 포함:
- **빌드 검증**: `xcodebuild -scheme CopilotMonitor build`
- **런타임 검증**: 앱 실행 후 메뉴 클릭으로 기능 확인
- **엣지케이스**: 특수 상황 시뮬레이션 (월초, 오프라인 등)

---

## Task Flow

```
Task 0 (Pre-work: Model 정리)
    ↓
Task 1 (UsageHistory 모델)
    ↓
Task 2 (API 호출 로직) ──→ Task 3 (UsagePredictor 알고리즘) [병렬 가능]
    ↓                           ↓
Task 4 (서브메뉴 UI 구현) ←────┘
    ↓
Task 5 (캐싱 및 에러 처리)
    ↓
Task 6 (통합 테스트 및 마무리)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 2, 3 | API 호출과 예측 알고리즘은 독립적으로 개발 가능 |

| Task | Depends On | Reason |
|------|------------|--------|
| 1 | 0 | 모델 정리 후 새 모델 추가 |
| 2 | 1 | UsageHistory 모델 필요 |
| 3 | 1 | UsageHistory 모델 필요 |
| 4 | 2, 3 | API 데이터와 예측 알고리즘 모두 필요 |
| 5 | 4 | UI 완성 후 캐싱 통합 |
| 6 | 5 | 모든 기능 완성 후 통합 테스트 |

---

## TODOs

- [x] 0. [Pre-work] CopilotUsage 모델 중복 제거

  **What to do**:
  - `StatusBarController.swift:848-885`의 로컬 `CopilotUsage` 정의 제거
  - `Models/CopilotUsage.swift`만 사용하도록 정리
  - 필요시 import 문 추가
  - **디버그 JSON 파일 처리**: `/Users/kargnas/copilot_debug.json` 저장 코드 (`saveDebugJSON`, `:651-701`) 완전 제거
    - 이유: 프로덕션 빌드에서 불필요, 로컬 경로 하드코딩은 다른 환경에서 문제 발생
    - 대안: 필요시 `#if DEBUG` 조건부 컴파일로 감싸거나, 완전 삭제 권장
  
  **디버그 코드 처리 방식 (선택)**:
  ```swift
  // Option A: 완전 제거 (권장)
  // saveDebugJSON 호출부와 메서드 정의 모두 삭제
  
  // Option B: 조건부 컴파일 (디버그 시에만)
  #if DEBUG
  saveDebugJSON(data)
  #endif
  ```

  **Must NOT do**:
  - `CopilotUsage` 모델 구조 자체 변경
  - 기존 로직 동작 변경

  **Parallelizable**: NO (선행 작업)

  **References**:
  
  **Pattern References**:
  - `CopilotMonitor/CopilotMonitor/Models/CopilotUsage.swift` - 원본 모델 정의
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:849-879` - 제거 대상 중복 정의
  
  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 앱 실행 후 기존 기능 정상 동작 확인 (메뉴바 아이콘, 사용량 표시)

  **Commit**: YES ✅ `283eed6`
  - Message: `refactor: remove duplicate CopilotUsage model and debug code`
  - Files: `StatusBarController.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 1. UsageHistory 데이터 모델 생성

  **What to do**:
  - `Models/UsageHistory.swift` 파일 생성
  
  **Xcode 프로젝트 파일 추가 방법 (CRITICAL)**:
  
  > `Models/` 폴더는 이미 존재함 (`CopilotMonitor/CopilotMonitor/Models/CopilotUsage.swift` 참조).
  > 같은 폴더에 새 파일 추가.
  
  1. **파일 생성**: `CopilotMonitor/CopilotMonitor/Models/UsageHistory.swift` 경로에 Swift 파일 생성
  2. **Xcode 프로젝트 등록 (필수)**:
     - Xcode에서 `CopilotMonitor/CopilotMonitor.xcodeproj` 열기
     - 좌측 Navigator에서 `Models` 그룹 우클릭 → "Add Files to CopilotMonitor..."
     - `UsageHistory.swift` 선택, **Target Membership: CopilotMonitor** 체크 확인
     - **⚠️ CLI 파일 생성만으로는 Xcode 타깃에 자동 포함되지 않음. 반드시 Xcode UI에서 "Add Files" 수행 필요.**
  3. **import 불필요**: 같은 타깃(CopilotMonitor) 내 Swift 파일은 자동으로 서로 인식됨. 별도 import 없이 `UsageHistory`, `DailyUsage` 타입 사용 가능.
  
  **구조체 정의**:
    ```swift
    struct DailyUsage: Codable {
        let date: Date              // UTC 날짜
        let includedRequests: Double // 포함된 요청 수
        let billedRequests: Double   // 추가 과금 요청 수
        let grossAmount: Double      // 총 금액
        let billedAmount: Double     // 추가 과금 금액
        
        // ⚠️ UTC 캘린더 고정: 날짜 저장이 UTC이므로 요일 판별도 UTC로 통일
        private static let utcCalendar: Calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal
        }()
        
        var dayOfWeek: Int { Self.utcCalendar.component(.weekday, from: date) }
        var isWeekend: Bool { dayOfWeek == 1 || dayOfWeek == 7 }
    }
    
    struct UsageHistory: Codable {
        let fetchedAt: Date
        let days: [DailyUsage]       // ⚠️ 월 전체 데이터 저장 (UI 표시 7일과 별개)
        
        var totalIncludedRequests: Double { days.reduce(0) { $0 + $1.includedRequests } }
        var totalBilledAmount: Double { days.reduce(0) { $0 + $1.billedAmount } }
        
        // UI용 최근 7일 슬라이스
        var recentDays: [DailyUsage] { Array(days.prefix(7)) }
    }
    ```
  
  **데이터 범위 명확화 (CRITICAL)**:
  - `days`: API에서 받은 **월 전체 데이터** 저장 (예: 1월 1일~18일까지 18일치)
  - `totalIncludedRequests`: **월 누적 합계** (예측 알고리즘에서 "현재까지_총사용량"으로 사용)
  - `recentDays`: **UI 표시용 최근 7일** 슬라이스 (메뉴에 표시되는 데이터)
  
  > **Why**: 예측 알고리즘은 "월 누적 합계 + 남은 일수 예측"을 사용하므로, `days`에 월 전체를 저장해야 함. UI는 7일만 표시.

  **Must NOT do**:
  - 기존 `CopilotUsage` 모델 수정
  - Model별 breakdown 데이터 포함 (후속 버전)
  - `days`를 7일로 제한 (월 전체 저장해야 함)

  **Parallelizable**: NO (Task 2, 3의 선행 조건)

  **References**:
  
  **Pattern References**:
  - `CopilotMonitor/CopilotMonitor/Models/CopilotUsage.swift` - Codable 모델 패턴
  
  **API References**:
  - API 응답 구조: `table.rows[].cells[]` - 날짜, 요청수, 금액 데이터
  
  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 파일 존재: `ls CopilotMonitor/CopilotMonitor/Models/UsageHistory.swift` → 파일 표시됨

  **Commit**: YES ✅ `dbac715`
  - Message: `feat: add UsageHistory data model`
  - Files: `Models/UsageHistory.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 2. copilot_usage_table API 호출 로직 구현

  **What to do**:
  - `StatusBarController.swift`에 히스토리 fetch 메서드 추가
  - JavaScript fetch 코드:
    ```swift
    private func fetchUsageHistory(customerId: String) async -> UsageHistory? {
        let js = """
        return await (async function() {
            try {
                const res = await fetch('/settings/billing/copilot_usage_table?customer_id=\(customerId)&group=0&period=3&query=&page=1', {
                    headers: { 'Accept': 'application/json', 'x-requested-with': 'XMLHttpRequest' }
                });
                return await res.json();
            } catch(e) { return { error: e.toString() }; }
        })()
        """
        // ... callAsyncJavaScript 실행 및 파싱
    }
    ```
  
  **날짜 파싱 규칙 (구체적)**:
  - API 응답의 `cells[0].sortValue` 형식: `"2026-01-18 00:00:00 +0000 utc"`
  - DateFormatter 설정:
    ```swift
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z 'utc'"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    ```
  - rows 정렬: API는 **과거순** (오래된 날짜 먼저). 파싱 후 **최신순으로 정렬**
  - **저장**: 정렬된 **전체 rows**를 `UsageHistory.days`에 저장 (7일 제한 없음)
  - **UI용 7일**: `UsageHistory.recentDays` computed property로 `.prefix(7)` 슬라이스
  
  **숫자/금액 파싱 규칙 (전체 필드 매핑)**:
  
  | Index | API 필드 | DailyUsage 필드 | 파싱 규칙 | 의미 |
  |-------|----------|-----------------|-----------|------|
  | `cells[0].sortValue` | date | `date: Date` | DateFormatter 사용 | 날짜 |
  | `cells[1].value` | includedRequests | `includedRequests: Double` | 콤마 제거 → Double | **하루 동안 사용한 총 요청 수** (limit 내 포함분) |
  | `cells[2].value` | billedRequests | `billedRequests: Double` | 콤마 제거 → Double | 하루 동안 limit 초과로 추가 과금된 요청 수 |
  | `cells[3].value` | grossAmount | `grossAmount: Double` | `$` 제거 → Double | 총 금액 (달러) |
  | `cells[4].value` | billedAmount | `billedAmount: Double` | `$` 제거 → Double | 추가 과금 금액 (달러) |
  
  **파싱 코드 예시**:
  ```swift
  func parseDailyUsage(from cells: [[String: Any]]) -> DailyUsage? {
      // cells[0]: 날짜
      guard let sortValue = (cells[0] as? [String: Any])?["sortValue"] as? String,
            let date = dateFormatter.date(from: sortValue) else { return nil }
      
      // cells[1]: includedRequests (콤마 제거)
      let includedStr = (cells[1] as? [String: Any])?["value"] as? String ?? "0"
      let includedRequests = Double(includedStr.replacingOccurrences(of: ",", with: "")) ?? 0
      
      // cells[2]: billedRequests (콤마 제거)
      let billedReqStr = (cells[2] as? [String: Any])?["value"] as? String ?? "0"
      let billedRequests = Double(billedReqStr.replacingOccurrences(of: ",", with: "")) ?? 0
      
      // cells[3]: grossAmount ($ 제거)
      let grossStr = (cells[3] as? [String: Any])?["value"] as? String ?? "$0"
      let grossAmount = Double(grossStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
      
      // cells[4]: billedAmount ($ 제거)
      let billedStr = (cells[4] as? [String: Any])?["value"] as? String ?? "$0"
      let billedAmount = Double(billedStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
      
      return DailyUsage(date: date, includedRequests: includedRequests, 
                        billedRequests: billedRequests, grossAmount: grossAmount, 
                        billedAmount: billedAmount)
  }
  ```
  
  **`includedRequests` 의미 명확화**:
  - `includedRequests`: 해당 날짜에 사용한 **총 요청 수** (limit 내 포함분)
  - `history.totalIncludedRequests`: 월초부터 오늘까지 사용한 **월 누적 요청 수**
  - 예측 알고리즘의 "현재까지_총사용량"은 이 월 누적값을 사용
  
  **`UsageHistory.fetchedAt` 설정 규칙**:
  ```swift
  // fetchUsageHistoryNow() 내 API 성공 후
  let history = UsageHistory(
      fetchedAt: Date(),  // ← API fetch 완료 시점의 현재 시간
      days: parsedDays.sorted { $0.date > $1.date }  // 최신순 정렬
  )
  ```
  - `fetchedAt`은 **API 호출이 성공한 시점**의 `Date()`로 설정
  - 캐시에서 로드한 경우, 저장 시점의 `fetchedAt`이 그대로 유지됨
  
  **히스토리 fetch 타이머 연결점 (구체적)**:
  
  ```swift
  // StatusBarController 내 새로운 프로퍼티
  private var historyFetchTimer: Timer?
  private var usageHistory: UsageHistory?
  private var lastHistoryFetchResult: HistoryFetchResult = .none
  private var customerId: String?  // fetchCustomerId() 성공 시 저장
  
  enum HistoryFetchResult {
      case none           // 아직 fetch 안 함
      case success        // API 성공
      case failedWithCache // API 실패, 캐시 사용
      case failedNoCache   // API 실패, 캐시도 없음
  }
  ```
  
  **타이머 시작/중지 위치 (실제 코드 기준)**:
  
  | 이벤트 | 실제 코드 위치 | 동작 |
  |--------|---------------|------|
  | **시작** | `Notification.Name("billingPageLoaded")` 옵저버 블록 내 (`:473-478`) | `startHistoryFetchTimer()` 호출 추가 |
  | **즉시 fetch** | 타이머 시작 직후 | `fetchUsageHistoryNow()` 즉시 1회 실행 |
  | **주기적 fetch** | 5분 간격 | 타이머 fire 시 `fetchUsageHistoryNow()` |
  | **중지** | `Notification.Name("sessionExpired")` 옵저버 블록 내 (`:480-486`) | `historyFetchTimer?.invalidate()` 추가 |
  | **중지** | 앱 종료 시 | 자동 해제 (Timer는 RunLoop에서 제거됨) |
  
  **수정할 옵저버 코드 위치**:
  
  ```swift
  // setupNotificationObservers() 내 billingPageLoaded 옵저버 수정 (StatusBarController.swift:473-479)
  NotificationCenter.default.addObserver(forName: Notification.Name("billingPageLoaded"), object: nil, queue: .main) { [weak self] _ in
      logger.info("노티 수신: billingPageLoaded")
      guard let self = self else { return }
      Task { @MainActor [weak self] in
          self?.fetchUsage()
          self?.startHistoryFetchTimer()  // ← 추가
      }
  }
  
  // setupNotificationObservers() 내 sessionExpired 옵저버 수정 (StatusBarController.swift:480-486)
  NotificationCenter.default.addObserver(forName: Notification.Name("sessionExpired"), object: nil, queue: .main) { [weak self] _ in
      logger.info("노티 수신: sessionExpired")
      guard let self = self else { return }
      Task { @MainActor [weak self] in
          self?.historyFetchTimer?.invalidate()  // ← 추가
          self?.historyFetchTimer = nil
          self?.updateUIForLoggedOut()
      }
  }
  ```
  
  **webView 접근 경로 (실제 코드 기준)**:
  
  > **Important**: `StatusBarController`에는 `webView` 프로퍼티가 없음. 반드시 `AuthManager.shared.webView` 사용.
  
  ```swift
  private func fetchUsageHistoryNow() {
      guard let customerId = self.customerId else {
          logger.warning("fetchUsageHistoryNow: customerId가 nil, 스킵")
          return
      }
      
      let webView = AuthManager.shared.webView  // ← AuthManager에서 가져옴
      
      Task { @MainActor in
          // ... callAsyncJavaScript(in: webView, ...) 사용
      }
  }
  ```
  
  **customerId 저장 위치**:
  - `fetchCustomerId(webView:)` 성공 후 (`StatusBarController.swift:543-553`)
  - `performFetchUsage()` 내에서 `self.customerId = validId` 저장 추가
  
  **수동 Refresh 동작 (명확화)**:
  - **기존 Refresh 버튼** (`refreshAction`): `copilot_usage_card` API만 호출 (변경 없음)
  - **히스토리 fetch**: Refresh 버튼과 **연동하지 않음** (별도 타이머로만 갱신)
  - **Why**: 사용자가 빈번하게 Refresh 누를 수 있고, 히스토리 API는 덜 자주 바뀜

  **Must NOT do**:
  - 기존 `copilot_usage_card` 호출 코드 수정
  - Auto-refresh 타이머에 history fetch 포함

  **Parallelizable**: YES (Task 3과 병렬 가능)

  **References**:
  
  **Pattern References**:
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:654-694` - `fetchAndProcessUsageData` 메서드의 JS fetch 패턴
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:556-589` - `fetchCustomerIdFromAPI` 메서드의 callAsyncJavaScript 사용법
  
  **API References**:
  - 엔드포인트: `/settings/billing/copilot_usage_table?customer_id=X&group=0&period=3&query=&page=1`
  - 응답 구조:
    ```json
    {
      "table": {
        "rows": [{
          "id": "2026-01-18 00:00:00 +0000 UTC",
          "cells": [
            { "value": "Jan 18, 2026", "sortValue": "2026-01-18 00:00:00 +0000 utc" },
            { "value": "908.59" },  // includedRequests
            { "value": "215.95" },  // billedRequests
            { "value": "$44.98" },  // grossAmount
            { "value": "$8.64" }    // billedAmount
          ]
        }]
      }
    }
    ```

  **로그 출력 기준 (검증용)**:
  
  `fetchUsageHistoryNow()` 메서드 내에서 다음 로그 추가:
  
  ```swift
  // ⚠️ 검증용 로그 포맷터 (API 파싱용 dateFormatter와 별도)
  let logDateFormatter = DateFormatter()
  logDateFormatter.dateFormat = "yyyy-MM-dd"
  logDateFormatter.timeZone = TimeZone(identifier: "UTC")
  
  // fetch 시작 시
  logger.info("fetchUsageHistoryNow: 시작, customerId=\(customerId)")
  
  // 날짜 파싱 성공 시 (각 row마다) - 검증용 logDateFormatter 사용
  logger.info("fetchUsageHistoryNow: Parsed date: \(logDateFormatter.string(from: date))")
  
  // fetch 완료 시
  logger.info("fetchUsageHistoryNow: 완료, days.count=\(history.days.count), totalRequests=\(history.totalIncludedRequests)")
  
  // 에러 발생 시
  logger.error("fetchUsageHistoryNow: 실패 - \(error.localizedDescription)")
  ```
  
  > **Note**: `dateFormatter` (API 파싱용)는 `"yyyy-MM-dd HH:mm:ss Z 'utc'"` 포맷이지만, 로그 출력용 `logDateFormatter`는 `"yyyy-MM-dd"` 포맷을 사용하여 검증 시 읽기 쉽게 함.

  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 앱 실행 → 로그인 → 5분 대기 → 콘솔에 history fetch 로그 확인
    - **"수동 트리거"의 정의**: 테스트 시 5분을 기다리지 않으려면, 앱을 **종료 후 재시작**하면 됨 (앱 시작 시 즉시 fetch 실행됨)
    - 또는 디버그 빌드에서 타이머 간격을 일시적으로 30초로 변경하여 테스트
  - [x] 날짜 파싱 검증: 로그에 `"Parsed date: 2026-01-18"` 형식 출력
  - [x] 정렬 검증: 최신 날짜가 배열 첫 번째 (`days[0]`)

  **Commit**: YES ✅ `dbf6547`
  - Message: `feat: implement copilot_usage_table API integration`
  - Files: `App/StatusBarController.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 3. UsagePredictor 예측 알고리즘 구현

  **What to do**:
  - `Services/UsagePredictor.swift` 파일 생성
  
  **Services 폴더 생성 및 Xcode 프로젝트 등록 (CRITICAL)**:
  
  > `Services/` 폴더는 현재 존재하지 않음. 새로 생성 필요.
  
  1. **폴더 생성**: 
     ```bash
     mkdir -p CopilotMonitor/CopilotMonitor/Services
     ```
  2. **파일 생성**: `CopilotMonitor/CopilotMonitor/Services/UsagePredictor.swift` 경로에 Swift 파일 생성
  3. **Xcode 프로젝트 등록 (필수)**:
     - Xcode에서 `CopilotMonitor/CopilotMonitor.xcodeproj` 열기
     - 좌측 Navigator에서 `CopilotMonitor` 그룹 우클릭 → "New Group" → "Services" 이름 지정
     - `Services` 그룹 우클릭 → "Add Files to CopilotMonitor..."
     - `UsagePredictor.swift` 선택, **Target Membership: CopilotMonitor** 체크 확인
     - **⚠️ CLI 파일/폴더 생성만으로는 Xcode 타깃에 자동 포함되지 않음. 반드시 Xcode UI에서 "New Group" 및 "Add Files" 수행 필요.**
  4. **import 불필요**: 같은 타깃 내 Swift 파일은 자동 인식. `UsagePredictor`, `UsagePrediction`, `ConfidenceLevel` 타입 사용 가능.
  
  **UsagePredictor 인스턴스 관리 (CRITICAL)**:
  
  `StatusBarController.swift`에서 인스턴스 생성 및 보관:
  
  ```swift
  // StatusBarController.swift 상단 프로퍼티 선언부 (기존 프로퍼티들 근처)
  // 위치: StatusBarController class 내부, 다른 private var 선언 근처
  private let usagePredictor = UsagePredictor()  // 인스턴스 생성 (lazy 불필요, stateless)
  ```
  
  사용 위치 (`getHistoryUIState()` 내):
  ```swift
  private func getHistoryUIState() -> HistoryUIState {
      // ...
      if let currentUsage = self.currentUsage {
          prediction = usagePredictor.predict(history: history, currentUsage: currentUsage)
          // usagePredictor는 StatusBarController의 프로퍼티로 접근
      }
      // ...
  }
  ```
  
  **데이터 구조**:
    ```swift
    struct UsagePrediction {
        let predictedMonthlyRequests: Double  // 월말 예상 총 요청
        let predictedBilledAmount: Double     // 예상 추가 비용
        let confidenceLevel: ConfidenceLevel  // low/medium/high
        let daysUsedForPrediction: Int        // 예측에 사용된 일수
    }
    
    enum ConfidenceLevel: String {
        case low = "예측 정확도 낮음"
        case medium = "예측 정확도 보통"
        case high = "예측 정확도 높음"
    }
    
    class UsagePredictor {
        func predict(history: UsageHistory, currentUsage: CopilotUsage) -> UsagePrediction
    }
    ```
  
  **예측 알고리즘 정확한 수식**:
  
  #### Step 1: 가중 평균 일일 사용량 계산
  ```
  가중치 배열 (최신 → 과거):
    - days[0] (어제/오늘): 1.5
    - days[1]: 1.5
    - days[2]: 1.2
    - days[3]: 1.2
    - days[4]: 1.2
    - days[5]: 1.0
    - days[6]: 1.0
  
  가중합 = Σ(days[i].includedRequests × weights[i])
  가중치합 = Σ(weights[0..n])
  가중평균_일사용량 = 가중합 / 가중치합
  ```
  
  #### Step 2: 주중/주말 패턴 보정
  ```
  과거 데이터에서:
    주중평균 = Σ(주중 사용량) / 주중 일수  (weekday: 2-6, 월-금)
    주말평균 = Σ(주말 사용량) / 주말 일수  (weekend: 1,7, 일,토)
    
    IF 주말평균 == 0 AND 주중평균 > 0: 주말비율 = 0.1 (fallback)
    ELSE IF 주중평균 == 0: 주말비율 = 1.0
    ELSE: 주말비율 = 주말평균 / 주중평균
  
  남은 일수 계산:
    월_총일수 = Calendar.range(of: .day, in: .month, for: Date())
    오늘 = Calendar.component(.day, from: Date())
    남은일수 = 월_총일수 - 오늘
    
  남은 일수 중 주중/주말 분류:
    FOR each remainingDay:
      IF isWeekend(date): 남은주말수++
      ELSE: 남은주중수++
  ```
  
  #### Step 3: 월말 예상 총 사용량
  ```
  예상_남은_주중사용량 = 가중평균_일사용량 × 남은주중수
  예상_남은_주말사용량 = 가중평균_일사용량 × 주말비율 × 남은주말수
  
  현재까지_총사용량 = history.totalIncludedRequests
  예상_월말_총사용량 = 현재까지_총사용량 + 예상_남은_주중사용량 + 예상_남은_주말사용량
  ```
  
  #### Step 4: 예상 추가 비용 계산
  ```
  limit = currentUsage.limitRequests
  
  IF 예상_월말_총사용량 > limit:
    초과_요청수 = 예상_월말_총사용량 - limit
    요청당_비용 = 0.04  // GitHub Copilot 기본 요금: $0.04/request
    예상_추가비용 = 초과_요청수 × 요청당_비용
  ELSE:
    예상_추가비용 = 0
  ```
  
  #### Step 5: Confidence Level 결정
  ```
  IF daysUsed < 3: ConfidenceLevel.low
  ELSE IF daysUsed < 7: ConfidenceLevel.medium
  ELSE: ConfidenceLevel.high
  ```
  
  **Edge case 처리**:
  - 모든 날이 0: `가중평균_일사용량 = 0` → `예상_월말 = 현재까지_총사용량`
  - 주말 데이터 없음: `주말비율 = 0.1` (주중의 10% fallback)
  - 데이터 0일: `return UsagePrediction(0, 0, .low, 0)`

  **Must NOT do**:
  - 외부 통계 라이브러리 사용
  - 복잡한 ML 모델 구현
  - 요청당 비용을 동적으로 계산 (고정값 $0.04 사용)

  **Parallelizable**: YES (Task 2와 병렬 가능)

  **References**:
  
  **Pattern References**:
  - `CopilotMonitor/CopilotMonitor/Models/CopilotUsage.swift:27-32` - computed property 패턴
  
  **Technical Context**:
  
  **⚠️ 캘린더/타임존 규칙 (CRITICAL)**:
  - **예측 알고리즘 내 모든 날짜 계산은 UTC 캘린더 사용**
  - 이유: `DailyUsage.date`가 UTC로 저장되므로, 요일/월/일수 계산도 UTC로 통일해야 일관성 유지
  
  ```swift
  // UsagePredictor 내 UTC 캘린더 정의
  private let utcCalendar: Calendar = {
      var cal = Calendar(identifier: .gregorian)
      cal.timeZone = TimeZone(identifier: "UTC")!
      return cal
  }()
  ```
  
  **계산 예시 (UTC 캘린더 사용)**:
  - 현재 월의 총 일수: `utcCalendar.range(of: .day, in: .month, for: Date())!.count`
  - 오늘 날짜 (월 내 일): `utcCalendar.component(.day, from: Date())`
  - 남은 일수 계산: 총 일수 - 오늘
  - 남은 날짜의 요일 판별: `utcCalendar.component(.weekday, from: futureDate)` (1=일요일, 7=토요일)
  - 요청당 비용: $0.04 (GitHub Copilot Premium Request 기준)
  
  **남은 일수 주중/주말 분류 코드**:
  ```swift
  func countRemainingWeekdaysAndWeekends(from today: Date, remainingDays: Int) -> (weekdays: Int, weekends: Int) {
      var weekdays = 0
      var weekends = 0
      
      for dayOffset in 1...remainingDays {
          guard let futureDate = utcCalendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
          let weekday = utcCalendar.component(.weekday, from: futureDate)
          if weekday == 1 || weekday == 7 {
              weekends += 1
          } else {
              weekdays += 1
          }
      }
      return (weekdays, weekends)
  }
  ```

  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 정량적 단위 테스트 시나리오 (수동 계산 검증):
    
    **시나리오 1: 정상 7일 데이터**
    - 입력 데이터:
      - `days` (최신→과거): [100, 120, 110, 90, 80, 20, 10] (주중 5일 + 주말 2일)
      - 월: 1월, 총 31일, 현재 18일차
      - 남은 일수: 13일 (주중 9일, 주말 4일 가정)
      - `currentUsage.limitRequests`: 1000
    - 계산 과정:
      - 가중합: 100×1.5 + 120×1.5 + 110×1.2 + 90×1.2 + 80×1.2 + 20×1.0 + 10×1.0 = **696**
      - 가중치합: 1.5+1.5+1.2+1.2+1.2+1.0+1.0 = **8.6**
      - 가중평균: 696/8.6 = **80.93**/day
      - 주중평균: (100+120+110+90+80)/5 = **100**
      - 주말평균: (20+10)/2 = **15**
      - 주말비율: 15/100 = **0.15**
      - 현재까지 총사용량: 100+120+110+90+80+20+10 = **530**
      - 예상 남은 주중: 80.93 × 9 = **728.37**
      - 예상 남은 주말: 80.93 × 0.15 × 4 = **48.56**
      - 예상 월말: 530 + 728.37 + 48.56 = **1306.93** requests
      - 초과: 1306.93 - 1000 = **306.93** requests
      - 예상 추가 비용: 306.93 × $0.04 = **$12.28**
    - **Expected Output**:
      - `predictedMonthlyRequests ≈ 1307` (±5%)
      - `predictedBilledAmount ≈ $12.28` (±5%)
      - `confidenceLevel = .high`
      - `daysUsedForPrediction = 7`
    
    **시나리오 2: 데이터 부족 (3일)**
    - 입력: [100, 120, 110], limit: 1000
    - Expected:
      - `confidenceLevel = .medium`
      - `daysUsedForPrediction = 3`
    
    **시나리오 3: 모든 날 0**
    - 입력: [0, 0, 0, 0, 0, 0, 0]
    - Expected:
      - `predictedMonthlyRequests = 0`
      - `predictedBilledAmount = 0`

  **Commit**: YES ✅ `9b38eaf`
  - Message: `feat: implement UsagePredictor algorithm`
  - Files: `Services/UsagePredictor.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 4. 히스토리/예측 서브메뉴 UI 구현

  **What to do**:
  - `StatusBarController.swift`에 서브메뉴 구성 추가 (별도 파일 생성하지 않음)
  
  **캐시 상태 → UI 전달 데이터 흐름 (구체적)**:
  
  ```swift
  // StatusBarController 내 상태 관리
  private var usageHistory: UsageHistory?           // 현재 표시할 히스토리 데이터
  private var lastHistoryFetchResult: HistoryFetchResult = .none
  private var historySubmenu: NSMenu!              // 히스토리 서브메뉴
  private var historyMenuItem: NSMenuItem!         // "📊 Usage History" 메뉴 아이템
  
  // 서브메뉴 렌더링 시 사용할 데이터
  struct HistoryUIState {
      let history: UsageHistory?
      let prediction: UsagePrediction?
      let isStale: Bool           // 30분 초과
      let hasNoData: Bool         // 데이터 없음
  }
  
  private func getHistoryUIState() -> HistoryUIState {
      guard let history = usageHistory else {
          return HistoryUIState(history: nil, prediction: nil, isStale: false, hasNoData: true)
      }
      
      let isStale = isStale(history)
      
      // ⚠️ currentUsage nil 처리: 예측은 currentUsage 필요
      var prediction: UsagePrediction? = nil
      if let currentUsage = self.currentUsage {
          prediction = usagePredictor.predict(history: history, currentUsage: currentUsage)
      }
      // currentUsage가 nil이면 prediction도 nil → UI에서 예측 섹션 미표시
      
      return HistoryUIState(
          history: history,
          prediction: prediction,
          isStale: isStale && lastHistoryFetchResult == .failedWithCache,
          hasNoData: false
      )
  }
  ```
  
  **서브메뉴 UI 구현 방식 (구체적 - NSMenuItem 패턴)**:
  
  서브메뉴 생성은 기존 `Auto Refresh` 패턴 (`setupMenu():427-436`) 따름:
  
  ```swift
  // setupMenu() 내에서 서브메뉴 생성 (separator 후, signInItem 전)
  // 위치: menu.addItem(NSMenuItem.separator()) 직후
  
  historyMenuItem = NSMenuItem(title: "📊 Usage History", action: nil, keyEquivalent: "")
  historySubmenu = NSMenu()
  historyMenuItem.submenu = historySubmenu
  menu.addItem(historyMenuItem)
  
  // 초기 상태로 "로딩 중..." 표시
  let loadingItem = NSMenuItem(title: "로딩 중...", action: nil, keyEquivalent: "")
  loadingItem.isEnabled = false
  historySubmenu.addItem(loadingItem)
  ```
  
  **서브메뉴 아이템 생성 방식 (헬퍼 없이 직접 NSMenuItem 사용)**:
  
  ```swift
  private func updateHistorySubmenu() {
      let state = getHistoryUIState()
      historySubmenu.removeAllItems()
      
      // Case 1: 데이터 없음
      if state.hasNoData {
          let item = NSMenuItem(title: "데이터 없음", action: nil, keyEquivalent: "")
          item.isEnabled = false
          item.attributedTitle = NSAttributedString(
              string: "데이터 없음",
              attributes: [.foregroundColor: NSColor.tertiaryLabelColor]
          )
          historySubmenu.addItem(item)
          return
      }
      
      // Case 2: 예측 섹션 (currentUsage가 있을 때만 표시)
          if let prediction = state.prediction {
              let formatter = NumberFormatter()
              formatter.numberStyle = .decimal
              formatter.maximumFractionDigits = 0
              
              // 예상 월말
              let monthlyText = "예상 월말: \(formatter.string(from: NSNumber(value: prediction.predictedMonthlyRequests)) ?? "0") requests"
              let monthlyItem = NSMenuItem(title: monthlyText, action: nil, keyEquivalent: "")
              monthlyItem.isEnabled = false
              historySubmenu.addItem(monthlyItem)
              
              // 추가 비용 (> 0 시만)
              if prediction.predictedBilledAmount > 0 {
                  let costText = String(format: "예상 추가 비용: $%.2f", prediction.predictedBilledAmount)
                  let costItem = NSMenuItem(title: costText, action: nil, keyEquivalent: "")
                  costItem.isEnabled = false
                  costItem.attributedTitle = NSAttributedString(
                      string: costText,
                      attributes: [.foregroundColor: NSColor.systemOrange]
                  )
                  historySubmenu.addItem(costItem)
              }
              
              // Confidence (low/medium만)
              if prediction.confidenceLevel == .low {
                  let confItem = NSMenuItem(title: "⚠️ 예측 정확도 낮음", action: nil, keyEquivalent: "")
                  confItem.isEnabled = false
                  confItem.attributedTitle = NSAttributedString(
                      string: "⚠️ 예측 정확도 낮음",
                      attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                  )
                  historySubmenu.addItem(confItem)
              } else if prediction.confidenceLevel == .medium {
                  let confItem = NSMenuItem(title: "📊 예측 정확도 보통", action: nil, keyEquivalent: "")
                  confItem.isEnabled = false
                  confItem.attributedTitle = NSAttributedString(
                      string: "📊 예측 정확도 보통",
                      attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                  )
                  historySubmenu.addItem(confItem)
              }
              
              // 예측 섹션이 표시된 경우에만 separator 추가
              historySubmenu.addItem(NSMenuItem.separator())
          }
          // currentUsage가 nil이면 state.prediction도 nil이므로 예측 섹션 스킵됨
      
      // Case 3: Stale 표시
      if state.isStale {
          let staleItem = NSMenuItem(title: "⏱️ 데이터가 오래됨", action: nil, keyEquivalent: "")
          staleItem.isEnabled = false
          staleItem.attributedTitle = NSAttributedString(
              string: "⏱️ 데이터가 오래됨",
              attributes: [.foregroundColor: NSColor.tertiaryLabelColor]
          )
          historySubmenu.addItem(staleItem)
      }
      
      // Case 4: 히스토리 섹션
      if let history = state.history {
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "MMM d"
          dateFormatter.timeZone = TimeZone(identifier: "UTC")  // UTC 기준으로 날짜 포맷
          
          // ⚠️ UTC 캘린더로 "오늘" 판별 (DailyUsage.date가 UTC이므로 일관성 유지)
          var utcCalendar = Calendar(identifier: .gregorian)
          utcCalendar.timeZone = TimeZone(identifier: "UTC")!
          let today = utcCalendar.startOfDay(for: Date())
          
          let numberFormatter = NumberFormatter()
          numberFormatter.numberStyle = .decimal
          numberFormatter.maximumFractionDigits = 0
          
          for day in history.recentDays {
              let dayStart = utcCalendar.startOfDay(for: day.date)
              let isToday = dayStart == today
              let dateStr = dateFormatter.string(from: day.date)
              let reqStr = numberFormatter.string(from: NSNumber(value: day.includedRequests)) ?? "0"
              let label = isToday ? "\(dateStr) (오늘): \(reqStr) req" : "\(dateStr): \(reqStr) req"
              
              let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
              item.isEnabled = false
              item.attributedTitle = NSAttributedString(
                  string: label,
                  attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)]
              )
              historySubmenu.addItem(item)
          }
      }
  }
  ```
  
  **서브메뉴 업데이트 호출 타이밍 (구체적)**:
  
  | 이벤트 | 호출 위치 | 호출 메서드 |
  |--------|----------|------------|
  | **앱 시작 시** | `setupMenu()` 직후 | `updateHistorySubmenu()` (캐시 로드 후) |
  | **히스토리 fetch 성공** | `fetchUsageHistoryNow()` 완료 후 | `updateHistorySubmenu()` |
  | **히스토리 fetch 실패 (캐시 사용)** | `fetchUsageHistoryNow()` 에러 핸들링 후 | `updateHistorySubmenu()` |
  | **캐시 로드** | `loadHistoryCache()` 성공 후 (앱 시작 시) | `updateHistorySubmenu()` |
  | **currentUsage 갱신 (CRITICAL)** | `updateUIForSuccess(usage:)` 메서드 끝 (:777-781) | `updateHistorySubmenu()` |
  
  > **Why currentUsage 갱신 시 호출 필요**: 예측 섹션은 `currentUsage.limitRequests`가 있어야 표시됨. 히스토리 fetch가 먼저 완료되고 currentUsage가 나중에 갱신되는 경우, 이 호출 없이는 예측 섹션이 5분 후까지 표시되지 않을 수 있음.
  
  ```swift
  // updateUIForSuccess(usage:) 메서드 끝부분에 추가 (StatusBarController.swift :777-781)
  // 현재 코드:
  // private func updateUIForSuccess(usage: CopilotUsage) {
  //     statusBarIconView.update(used: usage.usedRequests, limit: usage.limitRequests, cost: usage.netBilledAmount)
  //     usageView.update(usage: usage)
  //     signInItem.isHidden = true
  // }
  //
  // 수정 후:
  private func updateUIForSuccess(usage: CopilotUsage) {
      statusBarIconView.update(used: usage.usedRequests, limit: usage.limitRequests, cost: usage.netBilledAmount)
      usageView.update(usage: usage)
      signInItem.isHidden = true
      
      // 히스토리 서브메뉴도 갱신 (currentUsage 변경 시 예측 섹션 영향)
      updateHistorySubmenu()
  }
  ```
  
  **currentUsage 설정 위치 확인**:
  - `fetchAndProcessUsageData()` 메서드 (:682-684)에서 `currentUsage = usage` 설정 후 `updateUIForSuccess(usage:)` 호출
  - 따라서 `updateUIForSuccess` 끝에 `updateHistorySubmenu()` 추가하면 currentUsage 설정 직후 히스토리 서브메뉴가 갱신됨
  
  ```swift
  // 호출 패턴 예시 (fetchUsageHistoryNow 내부)
  private func fetchUsageHistoryNow() {
      Task { @MainActor in
          // ... fetch 로직 ...
          
          if let history = parsedHistory {
              self.usageHistory = history
              self.lastHistoryFetchResult = .success
              saveHistoryCache(history)
          } else if let cached = loadHistoryCache() {
              self.usageHistory = cached
              self.lastHistoryFetchResult = .failedWithCache
          } else {
              self.usageHistory = nil
              self.lastHistoryFetchResult = .failedNoCache
          }
          
          // ⚠️ 항상 호출하여 UI 갱신
          self.updateHistorySubmenu()
      }
  }
  ```
  
  **메뉴 구조 및 정확한 표시 위치**:
    ```
    [기존 UsageMenuItemView]           ← 위치: menu.items[0]
    ───────────────────────           ← 위치: menu.items[1] (separator)
    📊 Usage History ▶                ← 위치: menu.items[2] (새로 추가)
        │
        └─ [서브메뉴 구조]:
           ├─ [예측 섹션 - currentUsage가 있을 때만 표시]
           │   ├─ "예상 월말: 1,234 requests"     ← submenu.items[0]
           │   ├─ "예상 추가 비용: $12.34"        ← submenu.items[1] (예상비용 > 0 시만)
           │   └─ "⚠️ 예측 정확도 낮음"           ← submenu.items[2] (confidence == .low 시만)
           │
           ├─ ─────────────────                  ← submenu separator (예측 표시 시만)
           │
           └─ [히스토리 섹션 - 최근 7일] (항상 표시, history가 있을 때)
               ├─ "Jan 18 (오늘): 908 req"       ← submenu.items[N]
               ├─ "Jan 17: 350 req"
               └─ ... (최대 7일)
    ───────────────────────           ← 위치: menu.items[3] (기존 separator 위치 조정)
    Sign In                           ← 위치: menu.items[4]
    [Refresh]                         ← 위치: menu.items[5]
    ...
    ```
    
  **예측 섹션 표시 조건 (명확화)**:
  - `currentUsage != nil` → 예측 섹션 표시 (limitRequests 필요)
  - `currentUsage == nil` → 예측 섹션 숨김, 히스토리만 표시
  - 이유: 예측 알고리즘은 `currentUsage.limitRequests`가 필수이므로, 없으면 예측 불가
  
  **UI 메시지 표시 규칙**:
  
  | 상태 | 메시지 | 위치 | 스타일 |
  |------|--------|------|--------|
  | 예측값 표시 | `"예상 월말: {N} requests"` | submenu.items[0] | 기본 폰트 |
  | 추가 비용 > 0 | `"예상 추가 비용: ${amount}"` | submenu.items[1] | `NSColor.systemOrange` |
  | 추가 비용 == 0 | (표시 안 함) | - | - |
  | confidence == .low | `"⚠️ 예측 정확도 낮음"` | separator 직전 | `NSColor.secondaryLabelColor` |
  | confidence == .medium | `"📊 예측 정확도 보통"` | separator 직전 | `NSColor.secondaryLabelColor` |
  | confidence == .high | (표시 안 함) | - | - |
  | 캐시 사용 중 (stale) | `"⏱️ 데이터가 오래됨"` | 히스토리 섹션 최상단 | `NSColor.tertiaryLabelColor` |
  | 데이터 없음 | `"데이터 없음"` | submenu에 단독 표시 | `NSColor.tertiaryLabelColor` |
  
  **일별 히스토리 포맷**:
  - 오늘: `"Jan 18 (오늘): 908 req"`
  - 어제: `"Jan 17: 350 req"`
  - 숫자 포맷: `NumberFormatter` with `.decimal` style, 소수점 없음
  - 폰트: `NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)`

  **Must NOT do**:
  - Main menu에 예측값 직접 추가 (서브메뉴로만)
  - 스크롤 가능한 복잡한 UI
  - 차트/그래프 구현
  - 별도 `HistoryMenuView.swift` 파일 생성

  **Parallelizable**: NO (Task 2, 3 완료 필요)

  **References**:
  
  **Pattern References**:
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:409-454` - `setupMenu()` 메서드의 메뉴 구성 패턴
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:427-436` - 서브메뉴 구성 패턴 (Auto Refresh)
  - `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift:199-361` - `UsageMenuItemView` 커스텀 뷰 패턴 (참고용)
  
  **UI References**:
  - 추가 비용 강조색: `NSColor.systemOrange`
  - 보조 텍스트색: `NSColor.secondaryLabelColor`
  - 비활성 텍스트색: `NSColor.tertiaryLabelColor`
  - 숫자 폰트: `NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)`

  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 앱 실행 → 메뉴 클릭 → "📊 Usage History" 서브메뉴 존재 확인 (menu.items[2] 위치)
  - [x] 서브메뉴 hover → 예측 섹션 표시: "예상 월말: N requests"
  - [x] 예상 추가 비용 > 0 시: "예상 추가 비용: $X.XX" 오렌지색 표시
  - [x] confidence == .low 시: "⚠️ 예측 정확도 낮음" 표시
  - [x] 일별 히스토리 최대 7일 표시

  **Commit**: YES ✅ `d647950`
  - Message: `feat: add history and prediction submenu UI`
  - Files: `App/StatusBarController.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 5. 캐싱 및 에러 처리

  **What to do**:
  - 히스토리 데이터 캐싱:
    ```swift
    private func saveHistoryCache(_ history: UsageHistory) {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "copilot.history.cache")
        }
    }
    
    private func loadHistoryCache() -> UsageHistory? {
        guard let data = UserDefaults.standard.data(forKey: "copilot.history.cache") else { return nil }
        return try? JSONDecoder().decode(UsageHistory.self, from: data)
    }
    ```
  
  - **캐시 무효화 규칙 (구체적)**:
    
    #### 두 가지 시간 기준의 역할 구분 (CRITICAL)
    
    | 기준 | 임계값 | 역할 | 적용 결과 |
    |------|--------|------|-----------|
    | **Stale (UI 표시용)** | 30분 | UI에서 "⏱️ 데이터가 오래됨" 표시 여부 결정 | 캐시는 **계속 사용**, UI 경고만 추가 |
    | **월 변경 (캐시 삭제)** | 월 경계 | 캐시 완전 삭제 여부 결정 | 캐시 **삭제**, "데이터 없음" 표시 |
    
    > **Note**: 기존 `isCacheValid` 24시간 규칙은 **제거**합니다. 히스토리 데이터는 월 단위로 의미가 있으므로, 24시간 제한은 불필요합니다. 월이 바뀌지 않는 한 캐시는 항상 사용 가능합니다.
    
    #### Stale 표시 기준 (UI용, 30분)
    ```swift
    private func isStale(_ cache: UsageHistory) -> Bool {
        let staleThreshold: TimeInterval = 30 * 60  // 30분
        return Date().timeIntervalSince(cache.fetchedAt) > staleThreshold
    }
    ```
    - `isStale == true` && `lastHistoryFetchResult == .failedWithCache` → UI에 "⏱️ 데이터가 오래됨" 표시
    - `isStale == false` 또는 `lastHistoryFetchResult == .success` → 정상 표시
    
    #### 월 변경 검사 (캐시 삭제용)
    ```swift
    private func hasMonthChanged(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.month, from: date) != calendar.component(.month, from: Date())
            || calendar.component(.year, from: date) != calendar.component(.year, from: Date())
    }
    ```
    - 월이 바뀌면 → 캐시 삭제, "데이터 없음" 표시
    - 월이 같으면 → 캐시 사용 (30분 이상이면 Stale 표시 추가)
    
    #### 캐시 사용 결정 테이블 (단순화)
    | API 결과 | 월 변경 | 행동 |
    |----------|---------|------|
    | 성공 | - | 새 데이터 저장, `.success` 상태, UI 업데이트 |
    | 실패 | NO | 캐시 사용, `.failedWithCache` 상태, isStale 체크 → UI 업데이트 |
    | 실패 | YES | 캐시 삭제, `.failedNoCache` 상태, "데이터 없음" 표시 |
    
    #### 캐시 갱신 타이밍
    1. **앱 시작 시**: `loadCachedHistoryOnStartup()` → 캐시 있으면 즉시 UI 표시 → API fetch 시작
    2. **5분 타이머**: API fetch 성공 시 `saveHistoryCache()` 덮어쓰기
    3. **월 변경 감지 시**: 캐시 삭제 (`UserDefaults.standard.removeObject(forKey:)`)
    
    > **Note**: 수동 Refresh 버튼 (`refreshClicked`)은 기존 `copilot_usage_card` API만 호출하며, 히스토리 fetch와 **연동하지 않음**. 히스토리는 오직 5분 타이머로만 갱신됨.
    
    #### `HistoryFetchResult` 상태 정의 (명확화)
    
    ```swift
    enum HistoryFetchResult {
        case none           // 아직 fetch 안 함 (앱 초기 상태)
        case success        // API 성공 → 최신 데이터 사용 중
        case failedWithCache // API 실패했지만 캐시 사용 중 (앱 시작 캐시 로드 포함)
        case failedNoCache   // API 실패, 캐시도 없음 (월 변경으로 삭제된 경우 포함)
    }
    ```
    
    **`failedWithCache` 상태의 의미**:
    - API 실패 후 캐시 fallback 사용
    - **또는** 앱 시작 시 캐시 로드 (API fetch 전 상태)
    - 두 경우 모두 "캐시 데이터 표시 중"이라는 점에서 동일하게 처리
    - 이유: 앱 시작 직후에는 API fetch가 완료되지 않았으므로, 캐시를 표시하는 것이 적절함. 이후 API fetch 성공 시 `.success`로 전환됨.
    
    #### 캐시 유효성 로직 적용 위치 (구체적 코드 흐름)
    
    ```swift
    // 1. 앱 시작 시 - setupMenu() 내 historySubmenu 초기화 직후 호출
    //    (정확한 위치는 "호출 위치 요약" 섹션의 코드 블록 참조)
    private func loadCachedHistoryOnStartup() {
        guard let cached = loadHistoryCache() else {
            logger.info("캐시 없음 - 히스토리 로드 스킵")
            return
        }
        
        // 월 변경 체크 (hasMonthChanged 사용)
        if hasMonthChanged(cached.fetchedAt) {
            logger.info("월 변경 감지 - 캐시 삭제")
            UserDefaults.standard.removeObject(forKey: "copilot.history.cache")
            return
        }
        
        // 유효한 캐시 → UI에 즉시 표시
        self.usageHistory = cached
        self.lastHistoryFetchResult = .failedWithCache  // 캐시 사용 중 (API fetch 전)
        updateHistorySubmenu()  // isStale 체크 포함
    }
    
    // 2. fetchUsageHistoryNow() 내 API fetch 후
    private func fetchUsageHistoryNow() {
        // ... API fetch 로직 ...
        
        if let parsedHistory = parseApiResponse(response) {
            // API 성공
            self.usageHistory = parsedHistory
            self.lastHistoryFetchResult = .success
            saveHistoryCache(parsedHistory)
        } else if let cached = loadHistoryCache() {
            // API 실패, 캐시 사용
            if hasMonthChanged(cached.fetchedAt) {
                // 월 변경 시 캐시 삭제
                UserDefaults.standard.removeObject(forKey: "copilot.history.cache")
                self.usageHistory = nil
                self.lastHistoryFetchResult = .failedNoCache
            } else {
                // 월 동일 → 캐시 사용 (Stale 여부는 UI에서 판단)
                self.usageHistory = cached
                self.lastHistoryFetchResult = .failedWithCache
            }
        } else {
            // API 실패, 캐시 없음
            self.usageHistory = nil
            self.lastHistoryFetchResult = .failedNoCache
        }
        
        updateHistorySubmenu()  // isStale 체크 포함
    }
    ```
    
    **호출 위치 요약**:
    | 함수 | 호출 위치 | 동작 |
    |------|----------|------|
    | `loadCachedHistoryOnStartup()` | `setupMenu()` 내에서 **`historySubmenu` 초기화 직후** (Task 4의 서브메뉴 생성 코드 바로 다음 줄) | 앱 시작 시 캐시 로드 + 월 변경 체크 |
    | `loadHistoryCache()` | `fetchUsageHistoryNow()` 내 API 실패 시 | fallback으로 캐시 사용 |
    | `saveHistoryCache()` | `fetchUsageHistoryNow()` 내 API 성공 시 | 새 데이터 저장 |
    | `hasMonthChanged()` | `loadCachedHistoryOnStartup()`, `fetchUsageHistoryNow()` 내 | 월 변경 감지 → 캐시 삭제 결정 |
    | `isStale()` | `getHistoryUIState()` 내 | UI "⏱️ 데이터가 오래됨" 표시 결정 |
    
    **캐시 로드 호출 시점 (CRITICAL - 정확한 위치)**:
    
    ```swift
    // setupMenu() 내 - Task 4에서 historySubmenu 생성 후 바로 캐시 로드 호출
    // 위치: historyMenuItem.submenu = historySubmenu 직후
    
    historyMenuItem = NSMenuItem(title: "📊 Usage History", action: nil, keyEquivalent: "")
    historySubmenu = NSMenu()
    historyMenuItem.submenu = historySubmenu
    menu.addItem(historyMenuItem)
    
    // 초기 상태로 "로딩 중..." 표시
    let loadingItem = NSMenuItem(title: "로딩 중...", action: nil, keyEquivalent: "")
    loadingItem.isEnabled = false
    historySubmenu.addItem(loadingItem)
    
    // ⚠️ 캐시 로드는 반드시 historySubmenu 초기화 완료 후 호출
    // 이유: loadCachedHistoryOnStartup() 내부에서 updateHistorySubmenu() 호출 시 
    //       historySubmenu가 nil이면 crash 발생
    loadCachedHistoryOnStartup()  // ← 여기서 호출
    ```
    
    > **Why**: `loadCachedHistoryOnStartup()` 내부에서 `updateHistorySubmenu()`를 호출하며, 이 메서드는 `historySubmenu.removeAllItems()`를 실행함. `historySubmenu`가 초기화되기 전에 호출하면 nil 참조로 crash 발생.
  
  - **에러 처리**:
    - API 실패 시: 캐시된 데이터 사용, `isStale` 체크 후 "데이터가 오래됨" 표시
    - 파싱 실패 시: `logger.error()` 로깅 + 캐시 사용 시도
    - 빈 응답 시 (`rows.isEmpty`): "데이터 없음" 표시, 캐시 유지

  **Must NOT do**:
  - 기존 `copilot.usage.cache` 키 사용
  - 무한 캐시 (최대 24시간)

  **Parallelizable**: NO (Task 4 완료 필요)

  **References**:
  
  **Pattern References**:
  - `StatusBarController.swift:820-829` - `saveCache`, `loadCache` 메서드 패턴
  - `StatusBarController.swift:753-761` - `handleFetchFallback` 에러 핸들링 패턴

  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 앱 실행 → 히스토리 fetch 성공 → 앱 종료 → 재시작 → 캐시된 데이터 즉시 표시
  - [x] Wi-Fi 끄기 → 앱 실행 → 캐시된 데이터 표시 + "데이터가 오래됨" 표시

  **Commit**: YES ✅ `dc1e804`
  - Message: `feat: add history caching with month-change invalidation`
  - Files: `StatusBarController.swift`
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

- [x] 6. 통합 테스트 및 마무리

  **What to do**:
  - 전체 기능 통합 테스트
  - 엣지 케이스 테스트:
    - 월 1일~2일 (데이터 부족)
    - 모든 날 사용량 0
    - limit 초과 상태
    - 오프라인 상태
  - 로깅 정리:
    - 불필요한 logger 호출 제거 (히스토리 fetch 테스트용 로그 중 과도한 것 정리)
    - 중요 에러만 유지 (`logger.error`, `logger.warning`)
  
  > **Note**: `saveDebugJSON` 제거는 Task 0에서 이미 완료됨. 이 Task에서는 추가적인 디버그 코드 제거 없음.

  **Must NOT do**:
  - 새로운 기능 추가
  - 기존 기능 변경

  **Parallelizable**: NO (모든 Task 완료 필요)

  **References**:
  
  **Pattern References**:
  - `StatusBarController.swift:473-486` - 노티피케이션 옵저버 패턴 (타이머 연동 확인용)
  - `StatusBarController.swift:820-829` - 캐싱 패턴 (캐시 동작 검증용)

  **Acceptance Criteria**:
  
  **Manual Execution Verification:**
  - [x] 빌드: `cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build` → Build Succeeded
  - [x] 앱 실행 → 기존 기능 정상 동작 확인 (메뉴바 아이콘, 사용량)
  - [x] Usage History 서브메뉴 → 예측 + 히스토리 표시
  - [x] 앱 종료/재시작 → 캐시 정상 로드
  - [x] 1시간 방치 → 자동 갱신 정상 동작

  **Commit**: Task 6 (통합 테스트) 완료 - 코드 변경 없음
  - Message: `chore: complete integration testing and cleanup`
  - Files: N/A (no code changes needed)
  - Pre-commit: `xcodebuild -scheme CopilotMonitor build`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0 | `refactor: remove duplicate CopilotUsage model and debug code` | StatusBarController.swift | xcodebuild build |
| 1 | `feat: add UsageHistory data model` | Models/UsageHistory.swift | xcodebuild build |
| 2 | `feat: implement copilot_usage_table API integration` | StatusBarController.swift | xcodebuild build |
| 3 | `feat: implement UsagePredictor algorithm` | Services/UsagePredictor.swift | xcodebuild build |
| 4 | `feat: add history and prediction submenu UI` | StatusBarController.swift | xcodebuild build |
| 5 | `feat: add history data caching and error handling` | StatusBarController.swift | xcodebuild build |
| 6 | `chore: complete integration testing and cleanup` | StatusBarController.swift | xcodebuild build |

---

## Success Criteria

### Verification Commands
```bash
# 빌드 확인
cd CopilotMonitor && xcodebuild -scheme CopilotMonitor build
# Expected: ** BUILD SUCCEEDED **

# 앱 실행
open CopilotMonitor/build/Debug/CopilotMonitor.app
```

### Final Checklist
- [x] 메뉴에 "Usage History" 서브메뉴 존재
- [x] 예상 월말 사용량 표시됨
- [x] 예상 추가 비용 표시됨 (limit 초과 시)
- [x] 최근 7일 일별 사용량 표시됨
- [x] 데이터 부족 시 "예측 정확도 낮음" 표시
- [x] 오프라인 시 캐시된 데이터 표시
- [x] 기존 기능(메뉴바 아이콘, 현재 사용량) 정상 동작
- [x] 디버그 코드 없음

## ✅ IMPLEMENTATION COMPLETE (2026-01-18)

All tasks and acceptance criteria have been completed successfully.

**Commits:**
| Task | Commit | Message |
|------|--------|---------|
| 0 | `283eed6` | refactor: remove duplicate CopilotUsage model and debug code |
| 1 | `dbac715` | feat: add UsageHistory data model |
| 2 | `dbf6547` | feat: implement copilot_usage_table API integration |
| 3 | `9b38eaf` | feat: implement UsagePredictor algorithm |
| 4 | `d647950` | feat: add history and prediction submenu UI |
| 5 | `dc1e804` | feat: add history caching with month-change invalidation |
| 6 | N/A | Integration testing - no code changes needed |

**Build Status:** ✅ BUILD SUCCEEDED
