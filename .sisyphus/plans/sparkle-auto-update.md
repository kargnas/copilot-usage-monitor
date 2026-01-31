# Sparkle 자동 업데이트 기능 구현

## Context

### Original Request
macOS 메뉴바 앱 (CopilotMonitor)에 자동 업데이트 기능을 추가합니다.

### Interview Summary
**Key Discussions**:
- 업데이트 방식: Sparkle 프레임워크 (macOS 표준, 8.5k stars)
- Apple Developer ID: 이미 보유
- 배포 자동화: GitHub Actions + GitHub Releases
- 업데이트 동작: 완전 자동 (백그라운드 체크 → 다운로드 → 설치)
- Sandbox: 해제하여 단순화 (현재 sandboxed → non-sandboxed로 변경)
- Appcast 호스팅: GitHub Releases raw URL

**Research Findings**:
- Sparkle 2.x: macOS 10.13+, EdDSA 서명 필수
- Non-sandboxed 앱에서는 XPC 서비스 불필요
- GitHub Actions로 코드사인 + Notarization + appcast 생성 완전 자동화 가능

### Metis Review
**Identified Gaps** (addressed):
- Sandbox 상태: Sandbox 해제로 결정 → Entitlements 수정
- 코드사인 CI 설정: GitHub Actions workflow에 Developer ID 서명 추가
- XPC 서비스: Sandbox 해제로 불필요해짐
- EdDSA 키 관리: GitHub Secrets에 보관

---

## Work Objectives

### Core Objective
CopilotMonitor 앱에 Sparkle 2.x 기반 자동 업데이트 기능을 추가하여, GitHub Release 생성 시 자동으로 appcast.xml이 생성되고 사용자의 앱이 백그라운드에서 자동 업데이트됩니다.

### Concrete Deliverables
1. `Sparkle` 패키지가 SPM으로 추가된 Xcode 프로젝트
2. 업데이트 설정이 포함된 `Info.plist`
3. `SPUStandardUpdaterController`가 통합된 `AppDelegate.swift`
4. "Check for Updates..." 메뉴 항목이 추가된 `StatusBarController.swift`
5. 빌드/서명/Notarization/appcast 생성을 자동화하는 `.github/workflows/release.yml`
6. EdDSA 키 생성 및 GitHub Secrets 설정 가이드

### Definition of Done
- [x] 앱 빌드 성공: `xcodebuild -project CopilotMonitor.xcodeproj -scheme CopilotMonitor build`
- [x] 메뉴에서 "Check for Updates..." 클릭 시 업데이트 체크 수행
- [x] 24시간마다 자동으로 업데이트 체크
- [x] GitHub Release 생성 시 Actions가 **코드서명 + 공증 + appcast.xml 생성** 완료
- [x] 릴리스 DMG가 `spctl -a -vvv` 테스트 통과 ("Notarized Developer ID")
- [x] 구버전 앱에서 신버전 업데이트 설치 성공
- [x] 새 Mac에서 "App is damaged" 경고 없이 정상 설치

### Must Have
- Sparkle 2.x SPM 통합
- EdDSA 서명 키 설정
- Info.plist에 SUFeedURL, SUPublicEDKey 설정
- 완전 자동 업데이트 (SUAutomaticallyUpdate = true)
- **Apple Developer ID 코드 서명** (앱 번들 + DMG 전체)
- **Apple 공증 (Notarization)** + Stapling으로 Gatekeeper 통과
- GitHub Actions에서 코드사인 + Notarization 완전 자동화
- appcast.xml 자동 생성 및 Release에 업로드
- **Sparkle EdDSA 서명**으로 업데이트 무결성 검증

### Must NOT Have (Guardrails)
- ❌ Sandbox 유지 (XPC 서비스 복잡도 회피)
- ❌ Delta updates (첫 구현에서는 full update만)
- ❌ Beta channel 분리
- ❌ Custom 업데이트 UI (Sparkle 기본 UI 사용)
- ❌ HTTP URL 사용 (HTTPS만)
- ❌ `SUUpdater` 사용 (deprecated, Sparkle 1용)
- ❌ EdDSA private key 코드에 하드코딩

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (테스트 인프라 없음)
- **User wants tests**: Manual-only
- **Framework**: none

### Manual QA Only

각 TODO의 Acceptance Criteria에 상세한 수동 검증 절차 포함.

---

## Task Flow

```
Task 0 (EdDSA 키 생성)
    ↓
Task 1 (Sandbox 해제)
    ↓
Task 2 (Sparkle SPM 추가)
    ↓
Task 3 (Info.plist 설정)
    ↓
Task 4 (AppDelegate 수정)
    ↓
Task 5 (메뉴에 Check for Updates 추가)
    ↓
Task 6 (ExportOptions.plist 설정)
    ↓
Task 7 (GitHub Actions workflow - 코드서명/공증 포함)
    ↓
Task 8 (GitHub Secrets 설정)
    ↓
Task 9 (첫 릴리스 테스트)
```

## Parallelization

| Task | Depends On | Reason |
|------|------------|--------|
| 0 | None | 첫 작업 |
| 1 | 0 | 키 생성 후 진행 |
| 2 | 1 | Sandbox 해제 후 SPM 추가 |
| 3, 4, 5 | 2 | Sparkle 추가 후 병렬 가능 |
| 6 | 3, 4, 5 | 앱 코드 완료 후 Export 설정 |
| 7 | 6 | ExportOptions 완료 후 CI 작업 |
| 8 | 7 | Workflow 작성 후 Secrets 설정 |
| 9 | 8 | 모든 설정 완료 후 테스트 |

---

## TODOs

### - [x] 0. EdDSA 키 생성 (로컬 작업)

**What to do**:
1. Sparkle의 `generate_keys` 도구를 사용하여 EdDSA 키쌍 생성
2. Public key를 복사하여 Task 3에서 Info.plist에 추가
3. Private key를 안전하게 보관 (Task 7에서 GitHub Secrets에 추가)

**Must NOT do**:
- Private key를 코드나 레포에 커밋하지 않음
- 키를 분실하면 기존 사용자가 업데이트 불가

**Parallelizable**: NO (첫 작업)

**References**:
- Sparkle docs: https://sparkle-project.org/documentation/ - EdDSA 키 생성 가이드
- `generate_keys` 도구: Sparkle.framework/Versions/B/bin/generate_keys

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] Sparkle 도구 다운로드 또는 SPM 설치 후 bin 폴더 접근
- [x] 명령 실행: `./generate_keys -x` (또는 Sparkle repo에서 도구 실행)
- [x] 출력에서 Public key 확인: `SUPublicEDKey: <base64 string>`
- [x] Private key가 Keychain에 저장되었는지 확인
- [x] Public key를 별도 파일에 기록 (예: `sparkle_public_key.txt`)

**Commit**: NO (로컬 키 생성, 레포에 커밋 안 함)

---

### - [x] 1. Sandbox 해제

**What to do**:
1. `CopilotMonitor.entitlements` 파일에서 `com.apple.security.app-sandbox` 제거
2. 필요한 network.client 권한만 유지

**Must NOT do**:
- 다른 entitlements 건드리지 않음

**Parallelizable**: NO (순차)

**References**:
- **현재 파일**: `CopilotMonitor/CopilotMonitor/CopilotMonitor.entitlements:5-6` - 현재 sandbox=true 설정
- Apple docs: Entitlements 구조

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] 파일 수정 후 빌드: `xcodebuild -project CopilotMonitor/CopilotMonitor.xcodeproj -scheme CopilotMonitor build`
- [x] 빌드 성공 확인
- [x] 앱 실행하여 정상 동작 확인

**Commit**: YES
- Message: `chore: sandbox 해제 - Sparkle 통합 단순화를 위해`
- Files: `CopilotMonitor/CopilotMonitor/CopilotMonitor.entitlements`

---

### - [x] 2. Sparkle SPM 패키지 추가

**What to do**:
1. Xcode에서 File → Add Package Dependencies...
2. URL 입력: `https://github.com/sparkle-project/Sparkle`
3. Version: 2.x (최신 안정 버전)
4. Add to target: CopilotMonitor

**Must NOT do**:
- CocoaPods나 Carthage 사용 안 함
- Sparkle 1.x 버전 사용 안 함

**Parallelizable**: NO (순차)

**References**:
- Sparkle GitHub: https://github.com/sparkle-project/Sparkle
- SPM 통합 문서: https://sparkle-project.org/documentation/spm/

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] Xcode에서 패키지 추가 후 프로젝트 빌드 성공
- [x] `import Sparkle` 구문이 에러 없이 컴파일됨
- [x] Package.resolved 파일에 Sparkle 버전 기록됨

**Commit**: YES
- Message: `feat: Sparkle 2.x SPM 패키지 추가 - 자동 업데이트 기반`
- Files: `CopilotMonitor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

---

### - [x] 3. Info.plist에 Sparkle 설정 추가

**What to do**:
1. Info.plist에 다음 키 추가:
   - `SUFeedURL`: GitHub Release의 appcast.xml URL
   - `SUPublicEDKey`: Task 0에서 생성한 public key
   - `SUEnableAutomaticChecks`: true
   - `SUAutomaticallyUpdate`: true (완전 자동)
   - `SUScheduledCheckInterval`: 86400 (24시간)

**Must NOT do**:
- HTTP URL 사용 안 함 (HTTPS만)
- 잘못된 public key 입력 안 함

**Parallelizable**: YES (Task 4, 5와 병렬 가능)

**References**:
- **현재 파일**: `CopilotMonitor/CopilotMonitor/Info.plist` - 현재 Info.plist 위치
- Sparkle 설정 키: https://sparkle-project.org/documentation/customization/
- **Appcast URL 형식**: `https://github.com/kargnas/copilot-usage-monitor/releases/latest/download/appcast.xml`

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] Info.plist 열어서 SUFeedURL 값 확인
- [x] Public key가 Task 0에서 생성한 것과 일치하는지 확인
- [x] 빌드 성공 확인

**Commit**: YES
- Message: `feat: Sparkle 업데이트 설정 추가 - SUFeedURL, SUPublicEDKey, 자동 업데이트 활성화`
- Files: `CopilotMonitor/CopilotMonitor/Info.plist`

---

### - [x] 4. AppDelegate에 Sparkle Updater Controller 추가

**What to do**:
1. `import Sparkle` 추가
2. `SPUStandardUpdaterController` 인스턴스 생성
3. `applicationDidFinishLaunching`에서 업데이터 시작

**Must NOT do**:
- `SUUpdater` 사용 안 함 (deprecated)
- XIB/Storyboard 사용 안 함 (코드로만)

**Parallelizable**: YES (Task 3, 5와 병렬 가능)

**References**:
- **현재 파일**: `CopilotMonitor/CopilotMonitor/App/AppDelegate.swift:4-14` - @MainActor 클래스 구조
- Sparkle 프로그래매틱 사용: https://sparkle-project.org/documentation/programmatic-setup/
- SPUStandardUpdaterController 문서

**코드 패턴**:
```swift
import Sparkle

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // Sparkle Updater Controller - 자동 업데이트 관리
    // XIB 없이 코드로 초기화해야 함
    private var updaterController: SPUStandardUpdaterController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sparkle 초기화 - 앱 시작 시 자동 업데이트 체크 시작
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // ... 기존 코드
    }
}
```

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] 빌드 성공: `xcodebuild build`
- [x] 앱 실행 시 콘솔에 Sparkle 관련 로그 확인
- [x] 앱 시작 직후 업데이트 체크 시도 확인 (네트워크 요청)

**Commit**: YES
- Message: `feat: AppDelegate에 SPUStandardUpdaterController 추가 - 자동 업데이트 초기화`
- Files: `CopilotMonitor/CopilotMonitor/App/AppDelegate.swift`

---

### - [x] 5. 메뉴에 "Check for Updates..." 항목 추가

**What to do**:
1. StatusBarController의 메뉴 구성 부분에 "Check for Updates..." 항목 추가
2. 클릭 시 `updaterController.checkForUpdates(_:)` 호출
3. Sparkle의 updater를 접근하기 위해 AppDelegate에서 public으로 노출

**Must NOT do**:
- 메뉴 구조 전체를 변경하지 않음
- 기존 메뉴 항목 순서 변경하지 않음

**Parallelizable**: YES (Task 3, 4와 병렬 가능)

**References**:
- **현재 파일**: `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift` - 메뉴 구성 위치
- **AppDelegate**: 업데이터 컨트롤러 접근용

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] 앱 실행 후 메뉴바 클릭
- [x] "Check for Updates..." 메뉴 항목 표시 확인
- [x] 클릭 시 Sparkle 업데이트 체크 UI 표시 (또는 "최신 버전입니다" 알림)

**Commit**: YES
- Message: `feat: 메뉴에 Check for Updates 항목 추가`
- Files: `CopilotMonitor/CopilotMonitor/App/StatusBarController.swift`, `CopilotMonitor/CopilotMonitor/App/AppDelegate.swift`

---

### - [x] 6. ExportOptions.plist 코드서명 설정

**What to do**:
1. `ExportOptions.plist` 파일 확인 및 수정
2. Developer ID Application 서명을 위한 설정 추가

**필수 설정**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
```

**Must NOT do**:
- `method`를 `app-store`나 `development`로 설정하지 않음 (반드시 `developer-id`)
- Team ID를 하드코딩하지 않음 (GitHub Secrets 사용)

**Parallelizable**: NO (앱 코드 완료 후)

**References**:
- **현재 파일**: `ExportOptions.plist` - 루트에 이미 존재
- Apple docs: Xcode export options

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] ExportOptions.plist에 `method: developer-id` 설정 확인
- [x] `signingStyle: automatic` 설정 확인
- [x] Team ID가 변수화되어 있는지 확인

**Commit**: YES
- Message: `chore: ExportOptions.plist Developer ID 서명 설정`
- Files: `ExportOptions.plist`

---

### - [x] 7. GitHub Actions Release Workflow 생성 (코드서명 + 공증)

**What to do**:
1. `.github/workflows/release.yml` 생성
2. Release 생성 트리거로 시작
3. **완전한 파이프라인**: 빌드 → **코드서명** → **공증** → Staple → DMG 생성 → **Sparkle EdDSA 서명** → appcast.xml 생성 → Release 업로드

**코드서명 및 공증 상세 절차**:

#### Step 1: 임시 Keychain 생성 및 인증서 Import
```yaml
- name: Import Developer ID Certificate
  env:
    BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
    P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
    KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
  run: |
    # 인증서 디코딩
    CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
    echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $CERTIFICATE_PATH
    
    # 임시 Keychain 생성
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
    security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
    
    # 인증서 Import
    security import $CERTIFICATE_PATH -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
    security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
    security list-keychain -d user -s $KEYCHAIN_PATH
```

#### Step 2: 앱 빌드 및 Archive
```yaml
- name: Build and Archive
  run: |
    xcodebuild archive \
      -project CopilotMonitor/CopilotMonitor.xcodeproj \
      -scheme CopilotMonitor \
      -configuration Release \
      -archivePath $RUNNER_TEMP/CopilotMonitor.xcarchive \
      CODE_SIGN_IDENTITY="Developer ID Application" \
      DEVELOPMENT_TEAM="${{ secrets.APPLE_TEAM_ID }}" \
      CODE_SIGN_STYLE=Manual
```

#### Step 3: Archive Export (Developer ID 서명 포함)
```yaml
- name: Export Archive
  run: |
    xcodebuild -exportArchive \
      -archivePath $RUNNER_TEMP/CopilotMonitor.xcarchive \
      -exportPath $RUNNER_TEMP/export \
      -exportOptionsPlist ExportOptions.plist
```

#### Step 4: 앱 번들 코드서명 검증
```yaml
- name: Verify Code Signing
  run: |
    # 서명 검증
    codesign --verify --deep --strict --verbose=2 "$RUNNER_TEMP/export/CopilotMonitor.app"
    
    # Developer ID 인증서 확인
    codesign -dv --verbose=4 "$RUNNER_TEMP/export/CopilotMonitor.app" 2>&1 | grep "Authority"
```

#### Step 5: ZIP 생성 (Notarization용)
```yaml
- name: Create ZIP for Notarization
  run: |
    cd $RUNNER_TEMP/export
    ditto -c -k --keepParent CopilotMonitor.app CopilotMonitor.zip
```

#### Step 6: Apple 공증 (Notarization) 제출
```yaml
- name: Notarize App
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  run: |
    # 공증 제출 및 완료 대기
    xcrun notarytool submit $RUNNER_TEMP/export/CopilotMonitor.zip \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait \
      --timeout 30m
```

#### Step 7: Notarization Ticket Staple
```yaml
- name: Staple Notarization Ticket
  run: |
    # 공증 티켓을 앱에 첨부
    xcrun stapler staple "$RUNNER_TEMP/export/CopilotMonitor.app"
    
    # Staple 검증
    xcrun stapler validate "$RUNNER_TEMP/export/CopilotMonitor.app"
```

#### Step 8: DMG 생성 및 서명
```yaml
- name: Create and Sign DMG
  run: |
    # DMG 생성
    create-dmg \
      --volname "CopilotMonitor" \
      --volicon "CopilotMonitor/CopilotMonitor/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
      --window-pos 200 120 \
      --window-size 500 320 \
      --icon-size 80 \
      --icon "CopilotMonitor.app" 125 175 \
      --app-drop-link 375 175 \
      --hide-extension "CopilotMonitor.app" \
      "CopilotMonitor-${{ github.ref_name }}.dmg" \
      "$RUNNER_TEMP/export/"
    
    # DMG 코드서명
    codesign --force --sign "Developer ID Application: SANG RAK CHOI (${{ secrets.APPLE_TEAM_ID }})" \
      "CopilotMonitor-${{ github.ref_name }}.dmg"
```

#### Step 9: DMG 공증 (Optional but Recommended)
```yaml
- name: Notarize DMG
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  run: |
    xcrun notarytool submit "CopilotMonitor-${{ github.ref_name }}.dmg" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
    
    xcrun stapler staple "CopilotMonitor-${{ github.ref_name }}.dmg"
```

#### Step 10: Sparkle EdDSA 서명 및 appcast.xml 생성
```yaml
- name: Generate Sparkle Signature and Appcast
  env:
    SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
  run: |
    # Sparkle 도구 다운로드
    curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.6.0/Sparkle-2.6.0.tar.xz
    tar -xf sparkle.tar.xz
    
    # EdDSA 서명 생성
    SIGNATURE=$(./bin/sign_update "CopilotMonitor-${{ github.ref_name }}.dmg" --ed-key-file <(echo "$SPARKLE_PRIVATE_KEY"))
    
    # appcast.xml 생성 (또는 generate_appcast 사용)
    ./bin/generate_appcast \
      --ed-key-file <(echo "$SPARKLE_PRIVATE_KEY") \
      --download-url-prefix "https://github.com/kargnas/copilot-usage-monitor/releases/download/${{ github.ref_name }}/" \
      .
```

#### Step 11: Release에 업로드
```yaml
- name: Upload to Release
  uses: softprops/action-gh-release@v1
  with:
    files: |
      CopilotMonitor-${{ github.ref_name }}.dmg
      appcast.xml
```

**Must NOT do**:
- 인증서나 키를 workflow 파일에 하드코딩 안 함
- 공증 없이 배포 안 함 (Gatekeeper 차단됨)
- HTTP URL 사용 안 함

**Parallelizable**: NO (앱 코드 완료 후)

**References**:
- **현재 문서**: `docs/RELEASE_WORKFLOW.md` - 기존 수동 릴리스 절차
- Sparkle appcast 생성: `generate_appcast` 도구
- Apple Notarization: `notarytool submit --wait`
- GitHub Actions macOS runner: `macos-14` (Apple Silicon)

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] Workflow 파일이 `.github/workflows/release.yml`에 생성됨
- [x] 모든 코드서명/공증 단계가 포함되어 있는지 확인
- [x] Secrets 참조가 올바른지 확인 (BUILD_CERTIFICATE_BASE64, P12_PASSWORD 등)
- [x] GitHub repo에서 Actions 탭에서 workflow 표시 확인

**Commit**: YES
- Message: `ci: GitHub Actions Release workflow - Developer ID 코드서명, 공증, Sparkle appcast 자동화`
- Files: `.github/workflows/release.yml`

---

### - [x] 8. GitHub Secrets 설정 (수동 작업) ✅ COMPLETED

**What to do**:
1. GitHub repo → Settings → Secrets and variables → Actions
2. 다음 Secrets 추가:

**코드서명 및 공증 관련 Secrets**:

| Secret Name | Value | 설명 | 생성 방법 |
|------------|-------|------|----------|
| `BUILD_CERTIFICATE_BASE64` | Developer ID 인증서 .p12를 base64 인코딩 | 앱 코드서명용 | Keychain에서 "Developer ID Application" 인증서 내보내기 → `base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | 인증서 내보내기 시 설정한 암호 | .p12 암호 | 인증서 내보낼 때 설정 |
| `KEYCHAIN_PASSWORD` | 임시 키체인용 암호 | CI용 임시 키체인 | 아무 문자열 (예: `password123`) |
| `APPLE_ID` | Apple Developer 계정 이메일 | 공증 인증용 | developer.apple.com 계정 이메일 |
| `APPLE_APP_PASSWORD` | App-specific password | 공증 제출용 | appleid.apple.com → Sign-In and Security → App-Specific Passwords |
| `APPLE_TEAM_ID` | 10자리 Team ID | 개발자 식별 | developer.apple.com/account → Membership → Team ID |

**Sparkle 관련 Secrets**:

| Secret Name | Value | 설명 | 생성 방법 |
|------------|-------|------|----------|
| `SPARKLE_PRIVATE_KEY` | EdDSA private key | 업데이트 서명용 | Task 0에서 생성한 키 (Keychain Access → "Sparkle" 검색 → Export) |
| `SPARKLE_PUBLIC_KEY` | EdDSA public key | Info.plist에 설정 | Task 0에서 생성한 public key (선택적 - 백업용) |

**인증서 내보내기 상세 절차**:
```bash
# 1. Keychain Access 열기
open -a "Keychain Access"

# 2. "Developer ID Application: Your Name (TEAM_ID)" 인증서 찾기
# 3. 우클릭 → Export → .p12 형식으로 저장 (암호 설정)

# 4. Base64 인코딩
base64 -i "Developer_ID_Application.p12" | pbcopy

# 5. GitHub Secrets에 붙여넣기
```

**App-Specific Password 생성**:
1. https://appleid.apple.com 로그인
2. Sign-In and Security → App-Specific Passwords
3. "Generate Password" 클릭
4. 라벨: "GitHub Actions Notarization"
5. 생성된 16자리 암호를 `APPLE_APP_PASSWORD`로 저장

**Must NOT do**:
- Secrets를 코드에 커밋 안 함
- 만료된 인증서 사용 안 함
- App-Specific Password 대신 실제 Apple ID 암호 사용 안 함

**Parallelizable**: NO (Workflow 작성 후)

**References**:
- GitHub Secrets 문서: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- Apple App-specific password: https://support.apple.com/en-us/HT204397
- Developer ID 인증서: developer.apple.com/account/resources/certificates

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] GitHub repo Settings → Secrets에서 모든 7개 Secret 설정 확인:
  - BUILD_CERTIFICATE_BASE64 ✅
  - P12_PASSWORD ✅
  - KEYCHAIN_PASSWORD ✅
  - APPLE_ID ✅
  - APPLE_APP_PASSWORD ✅
  - APPLE_TEAM_ID (6YQH3QFFK8) ✅
  - SPARKLE_PRIVATE_KEY ✅
- [x] 각 Secret 이름이 workflow에서 참조하는 것과 일치 확인
- [x] Developer ID 인증서가 유효기간 내인지 확인

**Commit**: NO (GitHub UI에서 설정, 코드 커밋 없음)

---

### - [x] 9. 첫 테스트 릴리스 생성 및 검증 ✅ COMPLETED (v1.2)

**What to do**:
1. 버전 번호 업데이트 (예: 1.0.0 → 1.0.1)
2. GitHub에서 Release 생성 (tag: v1.0.1)
3. Actions workflow 실행 및 모든 단계 성공 확인
4. **코드서명 및 공증 검증**
5. appcast.xml이 Release에 업로드되었는지 확인
6. 이전 버전 앱에서 업데이트 동작 테스트

**공증 검증 방법**:
```bash
# 1. DMG 다운로드 후 공증 확인
spctl -a -vvv -t install CopilotMonitor-v1.0.1.dmg
# 출력: "CopilotMonitor-v1.0.1.dmg: accepted"
# 출력: "source=Notarized Developer ID"

# 2. 앱 번들 공증 확인 (DMG 마운트 후)
spctl -a -vvv -t execute /Volumes/CopilotMonitor/CopilotMonitor.app
# 출력: "CopilotMonitor.app: accepted"
# 출력: "source=Notarized Developer ID"

# 3. Staple 확인
xcrun stapler validate CopilotMonitor-v1.0.1.dmg
# 출력: "The validate action worked!"
```

**Gatekeeper 테스트**:
```bash
# 새 Mac 또는 VM에서 테스트
# 1. DMG 다운로드 (Safari/Chrome에서)
# 2. DMG 열기 → 앱을 Applications로 드래그
# 3. 앱 실행 → "App is damaged" 경고 없이 실행되어야 함
```

**Must NOT do**:
- 프로덕션 버전에서 바로 테스트 안 함 (별도 테스트 릴리스 사용)
- 공증 실패한 DMG 배포 안 함

**Parallelizable**: NO (마지막 작업)

**References**:
- GitHub Releases: https://github.com/kargnas/copilot-usage-monitor/releases
- 버전 번호: `Info.plist`의 `CFBundleShortVersionString`

**Acceptance Criteria**:

**Manual Execution Verification:**
- [x] Info.plist에서 버전 번호 업데이트 (1.1 → 1.2)
- [x] git tag 생성: `git tag v1.2 && git push origin v1.2`
- [x] GitHub에서 Release 생성 (tag: v1.2)
- [x] Actions 탭에서 Release workflow **모든 단계** 성공 확인:
  - Import Certificate ✅
  - Build and Archive ✅
  - Export Archive ✅
  - Verify Code Signing ✅
  - Notarize App ✅
  - Staple Ticket ✅
  - Create DMG ✅
  - Notarize DMG ✅
  - Generate Appcast ✅
  - Upload to Release ✅
- [x] Release 페이지에서 DMG 및 appcast.xml 파일 확인
- [x] 릴리스 검증 완료
- [x] 이전 버전 앱 실행 → 업데이트 알림 표시 확인 (Sparkle 작동)
- [x] 업데이트 설치 → 새 버전으로 앱 재시작 확인
- [x] 새 Mac에서 DMG 설치 테스트 → "App is damaged" 없이 정상 실행

**Commit**: Included in `0d599bb` (feat: Sparkle 2.8.1 자동 업데이트 통합)
- Message: `feat: Sparkle 2.8.1 자동 업데이트 통합`
- Files: Multiple files including Info.plist (version 1.2)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `chore: sandbox 해제` | .entitlements | Build success |
| 2 | `feat: Sparkle SPM 추가` | Package.resolved | Build success |
| 3 | `feat: Sparkle 설정 추가` | Info.plist | Build success |
| 4 | `feat: Updater Controller 추가` | AppDelegate.swift | Build success |
| 5 | `feat: Check for Updates 메뉴` | StatusBarController.swift | Menu visible |
| 6 | `chore: ExportOptions Developer ID 설정` | ExportOptions.plist | Valid plist |
| 7 | `ci: Release workflow (코드서명+공증)` | .github/workflows/release.yml | Workflow visible |
| 9 | `release: v1.0.1 (공증됨)` | Info.plist | Notarization success |

---

## Success Criteria

### Verification Commands
```bash
# 빌드 확인
xcodebuild -project CopilotMonitor/CopilotMonitor.xcodeproj -scheme CopilotMonitor build

# 앱 실행
open build/Release/CopilotMonitor.app

# 버전 확인
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" CopilotMonitor/CopilotMonitor/Info.plist

# 코드서명 확인 (로컬 빌드)
codesign --verify --deep --strict --verbose=2 build/Release/CopilotMonitor.app

# 공증 확인 (릴리스 DMG)
spctl -a -vvv -t install CopilotMonitor-v*.dmg
xcrun stapler validate CopilotMonitor-v*.dmg
```

### Final Checklist
- [x] ✅ Sparkle 2.x가 SPM으로 통합됨
- [x] ✅ Sandbox가 해제됨
- [x] ✅ Info.plist에 SUFeedURL, SUPublicEDKey 설정됨
- [x] ✅ 메뉴에 "Check for Updates..." 항목 표시됨
- [x] ✅ ExportOptions.plist에 Developer ID 설정됨
- [x] ✅ GitHub Actions workflow가 Release 시 실행됨
- [x] ✅ **앱 번들이 Developer ID로 코드서명됨**
- [x] ✅ **앱이 Apple에 공증(Notarized)됨**
- [x] ✅ **DMG가 코드서명 및 공증됨**
- [x] ✅ **공증 티켓이 Staple됨**
- [x] ✅ appcast.xml이 자동 생성되어 Release에 업로드됨
- [x] ✅ **Sparkle EdDSA 서명으로 업데이트 무결성 검증됨**
- [x] ✅ 이전 버전에서 새 버전으로 자동 업데이트 성공
- [x] ✅ 새 Mac에서 "App is damaged" 경고 없이 설치됨

---

## ✅ IMPLEMENTATION COMPLETE (2026-01-19)

All tasks have been successfully completed. v1.2 has been released with full Sparkle auto-update support.

**Summary:**
- Sparkle 2.8.1 integrated via SPM
- EdDSA keys generated and configured
- GitHub Actions workflow fully automated (build → sign → notarize → release)
- All 7 GitHub Secrets configured
- v1.2 released with notarized DMG and appcast.xml

**Release URL**: https://github.com/kargnas/copilot-usage-monitor/releases/tag/v1.2
