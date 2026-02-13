import Foundation
import os.log

private let logger = Logger(subsystem: "com.opencodeproviders", category: "CodexProvider")

final class CodexProvider: ProviderProtocol {
    let identifier: ProviderIdentifier = .codex
    let type: ProviderType = .quotaBased

    private struct RateLimitWindow: Codable {
        let used_percent: Double
        let limit_window_seconds: Int?
        let reset_after_seconds: Int?
        let reset_at: Int?
    }

    private struct RateLimit: Decodable {
        let windows: [String: RateLimitWindow]

        var primaryWindow: RateLimitWindow? {
            windows["primary_window"]
        }

        var secondaryWindow: RateLimitWindow? {
            windows["secondary_window"]
        }

        var sparkWindows: [(String, RateLimitWindow)] {
            windows
                .filter { $0.key.lowercased().contains("spark") }
                .map { ($0.key, $0.value) }
                .sorted { lhs, rhs in
                    lhs.0.localizedStandardCompare(rhs.0) == .orderedAscending
                }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            var parsed: [String: RateLimitWindow] = [:]
            for key in container.allKeys {
                if let window = try? container.decode(RateLimitWindow.self, forKey: key) {
                    parsed[key.stringValue] = window
                }
            }
            windows = parsed
        }

        struct DynamicCodingKey: CodingKey {
            var stringValue: String
            let intValue: Int? = nil

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue: Int) {
                nil
            }
        }
    }

    private struct CreditsInfo: Codable {
        let has_credits: Bool?
        let unlimited: Bool?
        let balance: String?
        let approx_local_messages: [Int]?
        let approx_cloud_messages: [Int]?

        var balanceAsDouble: Double? {
            guard let balance = balance else { return nil }
            return Double(balance)
        }
    }

    private struct CodexResponse: Decodable {
        struct AdditionalRateLimit: Decodable {
            let limit_name: String?
            let metered_feature: String?
            let rate_limit: RateLimit?
        }

        let plan_type: String?
        let rate_limit: RateLimit
        let additional_rate_limits: [AdditionalRateLimit]?
        let credits: CreditsInfo?
    }

    func fetch() async throws -> ProviderResult {
        let accounts = TokenManager.shared.getOpenAIAccounts()

        guard !accounts.isEmpty else {
            logger.error("No OpenAI accounts found for Codex")
            throw ProviderError.authenticationFailed("No OpenAI accounts configured")
        }

        var candidates: [CodexAccountCandidate] = []
        for account in accounts {
            do {
                let candidate = try await fetchUsageForAccount(account)
                candidates.append(candidate)
            } catch {
                logger.warning("Codex account fetch failed (\(account.authSource)): \(error.localizedDescription)")
            }
        }

        guard !candidates.isEmpty else {
            logger.error("Failed to fetch Codex usage for any account")
            throw ProviderError.providerError("All Codex account fetches failed")
        }

        let merged = CandidateDedupe.merge(
            candidates,
            accountId: { $0.accountId },
            isSameUsage: isSameUsage,
            priority: { sourcePriority($0.source) },
            mergeCandidates: mergeCandidates
        )
        let sorted = merged.sorted { lhs, rhs in
            sourcePriority(lhs.source) > sourcePriority(rhs.source)
        }

        let accountResults: [ProviderAccountResult] = sorted.enumerated().map { index, candidate in
            ProviderAccountResult(
                accountIndex: index,
                accountId: candidate.accountId,
                usage: candidate.usage,
                details: candidate.details
            )
        }

        let minRemaining = accountResults.compactMap { $0.usage.remainingQuota }.min() ?? 0
        let usage = ProviderUsage.quotaBased(remaining: minRemaining, entitlement: 100, overagePermitted: false)

        return ProviderResult(
            usage: usage,
            details: accountResults.first?.details,
            accounts: accountResults
        )
    }

    private struct CodexAccountCandidate {
        let accountId: String?
        let usage: ProviderUsage
        let details: DetailedUsage
        let sourceLabels: [String]
        let source: OpenAIAuthSource
    }

    private func sourcePriority(_ source: OpenAIAuthSource) -> Int {
        switch source {
        case .opencodeAuth:
            return 2
        case .codexLB:
            return 1
        case .codexAuth:
            return 0
        }
    }

    private func sourceLabel(_ source: OpenAIAuthSource) -> String {
        switch source {
        case .opencodeAuth:
            return "OpenCode"
        case .codexLB:
            return "Codex LB"
        case .codexAuth:
            return "Codex"
        }
    }

    private func mergeSourceLabels(_ primary: [String], _ secondary: [String]) -> [String] {
        var merged: [String] = []
        for label in primary + secondary {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !merged.contains(trimmed) else { continue }
            merged.append(trimmed)
        }
        return merged
    }

    private func sourceSummary(_ labels: [String], fallback: String) -> String {
        let merged = mergeSourceLabels(labels, [])
        if merged.isEmpty {
            return fallback
        }
        if merged.count == 1, let first = merged.first {
            return first
        }
        return merged.joined(separator: " + ")
    }

    private func mergeCandidates(primary: CodexAccountCandidate, secondary: CodexAccountCandidate) -> CodexAccountCandidate {
        let mergedLabels = mergeSourceLabels(primary.sourceLabels, secondary.sourceLabels)
        var mergedDetails = primary.details
        mergedDetails.authUsageSummary = sourceSummary(mergedLabels, fallback: "Unknown")

        // Fallback to secondary email when primary has none (different auth sources may carry different metadata)
        if mergedDetails.email == nil || mergedDetails.email?.isEmpty == true {
            mergedDetails.email = secondary.details.email
        }

        return CodexAccountCandidate(
            accountId: primary.accountId,
            usage: primary.usage,
            details: mergedDetails,
            sourceLabels: mergedLabels,
            source: primary.source
        )
    }

    private func fetchUsageForAccount(_ account: OpenAIAuthAccount) async throws -> CodexAccountCandidate {
        let endpoint = "https://chatgpt.com/backend-api/wham/usage"
        guard let url = URL(string: endpoint) else {
            logger.error("Invalid Codex API endpoint URL")
            throw ProviderError.networkError("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId = account.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        } else {
            logger.warning("Codex account ID missing for \(account.authSource), sending request without account header")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type from Codex API")
            throw ProviderError.networkError("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Codex API request failed with status code: \(httpResponse.statusCode)")
            throw ProviderError.networkError("HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let codexResponse: CodexResponse
        do {
            codexResponse = try decoder.decode(CodexResponse.self, from: data)
        } catch {
            logger.error("Failed to decode Codex API response: \(error.localizedDescription)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.error("Codex raw response: \(jsonString.prefix(1000))")
                let debugMsg = "[Codex] Raw response: \(jsonString)\n"
                if let debugData = debugMsg.data(using: .utf8) {
                    let path = "/tmp/provider_debug.log"
                    if let handle = FileHandle(forWritingAtPath: path) {
                        handle.seekToEndOfFile()
                        handle.write(debugData)
                        handle.closeFile()
                    }
                }
            }
            throw ProviderError.decodingError(error.localizedDescription)
        }

        guard let primaryWindow = codexResponse.rate_limit.primaryWindow else {
            logger.error("Codex response missing primary_window")
            throw ProviderError.decodingError("Missing primary window")
        }
        let secondaryWindow = codexResponse.rate_limit.secondaryWindow
        let additionalSparkLimit = codexResponse.additional_rate_limits?.first { limit in
            let name = limit.limit_name ?? ""
            return name.range(of: "spark", options: .caseInsensitive) != nil
                && limit.rate_limit?.primaryWindow != nil
        }
        let inlineSparkWindow = codexResponse.rate_limit.sparkWindows.first
        let primaryUsedPercent = primaryWindow.used_percent
        let primaryResetSeconds = primaryWindow.reset_after_seconds ?? 0
        let secondaryUsedPercent = secondaryWindow?.used_percent ?? 0.0
        let secondaryResetSeconds = secondaryWindow?.reset_after_seconds ?? 0
        let sparkUsedPercent = inlineSparkWindow?.1.used_percent
            ?? additionalSparkLimit?.rate_limit?.primaryWindow?.used_percent
        let sparkWindowLabel = normalizeSparkWindowLabel(inlineSparkWindow?.0 ?? additionalSparkLimit?.limit_name)
        let sparkResetSeconds = inlineSparkWindow?.1.reset_after_seconds
            ?? additionalSparkLimit?.rate_limit?.primaryWindow?.reset_after_seconds
        let sparkSecondaryUsedPercent = inlineSparkWindow == nil
            ? additionalSparkLimit?.rate_limit?.secondaryWindow?.used_percent
            : nil
        let sparkSecondaryResetSeconds = inlineSparkWindow == nil
            ? additionalSparkLimit?.rate_limit?.secondaryWindow?.reset_after_seconds
            : nil

        let now = Date()
        let primaryResetDate = now.addingTimeInterval(TimeInterval(primaryResetSeconds))
        let secondaryResetDate = secondaryWindow != nil ? now.addingTimeInterval(TimeInterval(secondaryResetSeconds)) : nil
        let sparkResetDate = sparkResetSeconds != nil ? now.addingTimeInterval(TimeInterval(sparkResetSeconds ?? 0)) : nil
        let sparkSecondaryResetDate = sparkSecondaryResetSeconds != nil ? now.addingTimeInterval(TimeInterval(sparkSecondaryResetSeconds ?? 0)) : nil

        let remaining = Int(100 - primaryUsedPercent)
        let sourceLabels = account.sourceLabels.isEmpty ? [sourceLabel(account.source)] : account.sourceLabels
        let authUsageSummary = sourceSummary(sourceLabels, fallback: "Unknown")
        let details = DetailedUsage(
            dailyUsage: primaryUsedPercent,
            secondaryUsage: secondaryUsedPercent,
            secondaryReset: secondaryResetDate,
            primaryReset: primaryResetDate,
            sparkUsage: sparkUsedPercent,
            sparkReset: sparkResetDate,
            sparkSecondaryUsage: sparkSecondaryUsedPercent,
            sparkSecondaryReset: sparkSecondaryResetDate,
            sparkWindowLabel: sparkWindowLabel,
            creditsBalance: codexResponse.credits?.balanceAsDouble,
            planType: codexResponse.plan_type,
            email: account.email,
            authSource: account.authSource,
            authUsageSummary: authUsageSummary
        )

        let sparkSummary = sparkUsedPercent.map { String(format: "%.1f%%", $0) } ?? "none"
        let sparkWeeklySummary = sparkSecondaryUsedPercent.map { String(format: "%.1f%%", $0) } ?? "none"
        let sparkSource: String
        if inlineSparkWindow != nil {
            sparkSource = "rate_limit"
        } else if additionalSparkLimit != nil {
            sparkSource = "additional_rate_limits"
        } else {
            sparkSource = "none"
        }
        logger.debug("Codex usage fetched (\(authUsageSummary)): email=\(account.email ?? "unknown"), primary=\(primaryUsedPercent)%, secondary=\(secondaryUsedPercent)%, spark_primary=\(sparkSummary), spark_secondary=\(sparkWeeklySummary), spark_source=\(sparkSource), plan=\(codexResponse.plan_type ?? "unknown"), spark_window=\(sparkWindowLabel ?? "none")")

        let usage = ProviderUsage.quotaBased(remaining: remaining, entitlement: 100, overagePermitted: false)
        return CodexAccountCandidate(
            accountId: account.accountId,
            usage: usage,
            details: details,
            sourceLabels: sourceLabels,
            source: account.source
        )
    }

    private func isSameUsage(_ lhs: CodexAccountCandidate, _ rhs: CodexAccountCandidate) -> Bool {
        let primaryMatch = lhs.details.dailyUsage == rhs.details.dailyUsage
        let secondaryMatch = lhs.details.secondaryUsage == rhs.details.secondaryUsage
        let primaryResetMatch = sameDate(lhs.details.primaryReset, rhs.details.primaryReset)
        let secondaryResetMatch = sameDate(lhs.details.secondaryReset, rhs.details.secondaryReset)
        let sparkUsageMatch = lhs.details.sparkUsage == rhs.details.sparkUsage
        let sparkResetMatch = sameDate(lhs.details.sparkReset, rhs.details.sparkReset)
        let sparkSecondaryUsageMatch = lhs.details.sparkSecondaryUsage == rhs.details.sparkSecondaryUsage
        let sparkSecondaryResetMatch = sameDate(lhs.details.sparkSecondaryReset, rhs.details.sparkSecondaryReset)
        let sparkWindowLabelMatch = lhs.details.sparkWindowLabel == rhs.details.sparkWindowLabel
        return primaryMatch
            && secondaryMatch
            && primaryResetMatch
            && secondaryResetMatch
            && sparkUsageMatch
            && sparkResetMatch
            && sparkSecondaryUsageMatch
            && sparkSecondaryResetMatch
            && sparkWindowLabelMatch
    }

    private func normalizeSparkWindowLabel(_ rawLabel: String?) -> String? {
        guard let rawLabel else { return nil }
        let normalized = rawLabel
            .replacingOccurrences(of: "_window", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        if normalized.lowercased() == normalized {
            return normalized.capitalized
        }
        return normalized
    }

    private func sameDate(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return Int(left.timeIntervalSince1970) == Int(right.timeIntervalSince1970)
        default:
            return false
        }
    }
}

private enum AnyCodable: Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}
