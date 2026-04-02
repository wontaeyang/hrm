import Carbon.HIToolbox

enum KeyCodeLabel {
    private static var cache: [UInt16: String] = [:]

    static func invalidateCache() {
        cache.removeAll()
    }

    static func label(for keyCode: UInt16) -> String {
        if let cached = cache[keyCode] {
            return cached
        }

        let result = translate(keyCode: keyCode)
        cache[keyCode] = result
        return result
    }

    private static func translate(keyCode: UInt16) -> String {
        let primarySource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let asciiSource = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue()
        let source = [primarySource, asciiSource].compactMap { $0 }.first {
            TISGetInputSourceProperty($0, kTISPropertyUnicodeKeyLayoutData) != nil
        }

        guard let source else {
            return String(format: "0x%02X", keyCode)
        }

        let layoutData = unsafeBitCast(
            TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData), to: CFData.self
        )
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &chars
        )

        if status == noErr, length > 0 {
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }

        return String(format: "0x%02X", keyCode)
    }
}
