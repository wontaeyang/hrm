import ApplicationServices
import Foundation

enum AccessibilityManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func ensureAccessibility(completion: @escaping (Bool) -> Void) {
        if isTrusted {
            completion(true)
            return
        }
        requestPermission()
        completion(false)
    }
}
