import Foundation
import Sparkle

@main enum UpdateFeedbackTests {
    static func main() {
        var checks = 0
        func check(_ value: Bool, _ label: String) {
            precondition(value, label)
            checks += 1
        }
        check(!UpdateFeedback.isCurrentOrAhead(currentBuild: "47", latestBuild: "61"), "new build remains eligible")
        check(UpdateFeedback.isCurrentOrAhead(currentBuild: "61", latestBuild: "61"), "same build")
        check(UpdateFeedback.isCurrentOrAhead(currentBuild: "61", latestBuild: "47"), "stale feed cannot imply downgrade")
        for invalid in [nil, "", "0", "bad", "-1"] as [String?] {
            check(!UpdateFeedback.isCurrentOrAhead(currentBuild: "61", latestBuild: invalid), "invalid feed")
        }
        // Public initializer is used only to construct a fixture, never for update decisions.
        let item = SUAppcastItem(dictionary: ["enclosure": ["url": "https://example.com/NotchMuse.dmg", "sparkle:version": "47"]])!
        let original = NSError(domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue), userInfo: [
            SPULatestAppcastItemFoundKey: item,
            SPUNoUpdateFoundReasonKey: NSNumber(value: SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue),
            "preserved": "value"
        ])
        for chinese in [true, false] {
            let result = UpdateFeedback.noUpdateError(original, version: "0.8.1", build: "61", chinese: chinese)
            check(result.localizedDescription == (chinese ? "已是最新版本" : "You're up to date"), "correct user conclusion")
            check(result.code == original.code && result.domain == original.domain && (result.userInfo["preserved"] as? String) == "value", "error semantics preserved")
            check(!result.localizedRecoverySuggestion!.contains("0.8.0"), "do not call older version newest")
        }
        let unknown = UpdateFeedback.noUpdateError(NSError(domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue)), version: "0.8.1", build: "61", chinese: true)
        check(unknown.localizedDescription == "无法确认更新状态", "empty/invalid data is not a success")
        for code in [NSURLErrorTimedOut, NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost] {
            let network = NSError(domain: NSURLErrorDomain, code: code)
            check(UpdateFeedback.isNetworkError(network), "network recoverable")
            check(UpdateFeedback.isNetworkError(NSError(domain: SUSparkleErrorDomain, code: 1001, userInfo: [NSUnderlyingErrorKey: network])), "nested network failure")
        }
        check(!UpdateFeedback.isNetworkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)), "no retry on cancellation")
        check(!UpdateFeedback.isNetworkError(NSError(domain: SUSparkleErrorDomain, code: 1002)), "integrity failure keeps Sparkle explanation")
        print("PASS: \(checks) update-feedback checks")
    }
}
