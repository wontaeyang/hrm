import ApplicationServices
import CoreGraphics
import Foundation

enum AccessibilityManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var isInputMonitoringGranted: Bool {
        CGPreflightListenEventAccess()
    }

    static var hasAllPermissions: Bool {
        isTrusted && isInputMonitoringGranted
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoring() {
        CGRequestListenEventAccess()
    }

    static func ensureAllPermissions(completion: @escaping (Bool) -> Void) {
        if hasAllPermissions {
            completion(true)
            return
        }

        // Request Accessibility first if needed
        if !isTrusted {
            requestAccessibility()
        }

        // Poll for both permissions
        var attempts = 0
        var didRequestInputMonitoring = false
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            attempts += 1

            let axGranted = AXIsProcessTrusted()
            let imGranted = CGPreflightListenEventAccess()

            // Once Accessibility is granted, request Input Monitoring once if still needed
            if axGranted && !imGranted && !didRequestInputMonitoring {
                didRequestInputMonitoring = true
                CGRequestListenEventAccess()
            }

            if axGranted && imGranted {
                timer.invalidate()
                completion(true)
            } else if attempts > 120 {
                timer.invalidate()
                completion(false)
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
}
