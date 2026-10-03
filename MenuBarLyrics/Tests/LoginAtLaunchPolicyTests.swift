import Foundation
import ServiceManagement

// Run with swiftc alongside App/LoginAtLaunchPolicy.swift; no real login items are changed.
@main
struct LoginAtLaunchPolicyTests {
    @MainActor
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        func fixture(_ body: (UserDefaults, String) throws -> Void) rethrows {
            let domain = "NotchMuse.LoginAtLaunchPolicyTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: domain)!
            defer { defaults.removePersistentDomain(forName: domain) }
            try body(defaults, domain)
        }
        func configure(_ defaults: UserDefaults, _ domain: String,
                       preview: Bool = false, status: SMAppService.Status = .notRegistered,
                       register: () throws -> Void) {
            LoginAtLaunchPolicy.configureIfNeeded(defaults: defaults, bundleID: domain,
                                                  isPreview: preview, status: status, register: register)
        }

        fixture { defaults, domain in
            var registrations = 0
            configure(defaults, domain) { registrations += 1 }
            check(registrations == 1, "Stable fresh install defaults ON")
            check(defaults.bool(forKey: LoginAtLaunchPolicy.initializedKey), "Stable initialized")
            check(defaults.object(forKey: LoginAtLaunchPolicy.pendingNewInstallKey) == nil, "Pending cleared")
            configure(defaults, domain) { registrations += 1 }
            check(registrations == 1, "Stable does not override later system OFF")
        }
        fixture { defaults, domain in
            defaults.set("en", forKey: "Language")
            var registrations = 0
            configure(defaults, domain) { registrations += 1 }
            check(registrations == 0, "Existing Stable preference stays OFF")
            check(defaults.string(forKey: "Language") == "en", "Existing preference unchanged")
        }
        for status: SMAppService.Status in [.enabled, .requiresApproval, .notFound] {
            fixture { defaults, domain in
                var registrations = 0
                configure(defaults, domain, status: status) { registrations += 1 }
                check(registrations == 0, "Existing Stable system status preserved")
            }
        }
        for status: SMAppService.Status in [.notRegistered, .enabled, .requiresApproval] {
            fixture { defaults, domain in
                var registrations = 0
                configure(defaults, domain, preview: true, status: status) { registrations += 1 }
                check(registrations == 0, "Preview preserves default OFF or existing ON")
                check(defaults.bool(forKey: LoginAtLaunchPolicy.initializedKey), "Preview initialized")
                configure(defaults, domain, preview: true, status: status) { registrations += 1 }
                check(registrations == 0, "Preview restart leaves system status alone")
            }
        }
        for preview in [false, true] {
            for status: SMAppService.Status in [.enabled, .notRegistered] {
                fixture { defaults, domain in
                    defaults.set(true, forKey: LoginAtLaunchPolicy.pendingNewInstallKey)
                    LoginAtLaunchPolicy.markUserChoice(defaults: defaults)
                    check(defaults.object(forKey: LoginAtLaunchPolicy.pendingNewInstallKey) == nil,
                          "Explicit ON/OFF cancels pending registration")
                    let reloaded = UserDefaults(suiteName: domain)!
                    check(reloaded.bool(forKey: LoginAtLaunchPolicy.initializedKey), "User choice persisted")
                    var registrations = 0
                    configure(reloaded, domain, preview: preview, status: status) { registrations += 1 }
                    check(registrations == 0, "Explicit ON/OFF survives restart")
                }
            }
        }
        fixture { defaults, domain in
            enum Failure: Error { case registration }
            configure(defaults, domain) { throw Failure.registration }
            check(!defaults.bool(forKey: LoginAtLaunchPolicy.initializedKey), "Failed registration can retry")
            check(defaults.bool(forKey: LoginAtLaunchPolicy.pendingNewInstallKey), "Fresh-install decision retained")
            var registrations = 0
            configure(defaults, domain) { registrations += 1 }
            check(registrations == 1, "Stable retries failed fresh registration")
        }
        fixture { defaults, domain in
            defaults.set(true, forKey: LoginAtLaunchPolicy.pendingNewInstallKey)
            var registrations = 0
            configure(defaults, domain, preview: true) { registrations += 1 }
            check(registrations == 0, "Preview never retries stale default ON")
            check(defaults.object(forKey: LoginAtLaunchPolicy.pendingNewInstallKey) == nil, "Preview clears pending")
        }
        print("LoginAtLaunchPolicy: \(checks) checks passed")
    }
}
