import ApplicationServices
import Foundation

enum AccessibilityManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func ensureAccessibility(completion: @escaping (Bool) -> Void) {
        if isTrusted {
            completion(true)
            return
        }

        requestPermission()

        // Poll for permission grant
        var attempts = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            attempts += 1
            if AXIsProcessTrusted() {
                timer.invalidate()
                completion(true)
            } else if attempts > 60 {
                timer.invalidate()
                completion(false)
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
}
