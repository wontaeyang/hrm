import Testing
import Foundation
@testable import HRM

@Suite("ConfigurationStore Tests")
struct ConfigurationStoreTests {
    private func makeTempDirectory() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("HRMTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    @Test("Default configuration loads when no file exists")
    func loadDefaultWhenNoFile() throws {
        let dir = try makeTempDirectory()
        let store = ConfigurationStore(directory: dir)
        let config = store.load()
        #expect(config.enabled == true)
        #expect(config.quickTapTermMs == 150)
        #expect(config.keyBindings.count == 10)
    }

    @Test("Save and load round-trip preserves configuration")
    func saveLoadRoundTrip() throws {
        let dir = try makeTempDirectory()
        let store = ConfigurationStore(directory: dir)

        var config = DefaultConfiguration.make()
        config.quickTapTermMs = 150
        config.requirePriorIdleMs = 100

        try store.save(config)
        let loaded = store.load()

        #expect(loaded.quickTapTermMs == 150)
        #expect(loaded.requirePriorIdleMs == 100)
        #expect(loaded.keyBindings.count == 10)
    }

    @Test("Per-key overrides round-trip correctly")
    func perKeyOverridesRoundTrip() throws {
        let dir = try makeTempDirectory()
        let store = ConfigurationStore(directory: dir)

        var config = DefaultConfiguration.make()
        config.keyBindings[0].bilateralFiltering = false
        config.keyBindings[0].quickTapTermMs = 200

        try store.save(config)
        let loaded = store.load()

        #expect(loaded.keyBindings[0].bilateralFiltering == false)
        #expect(loaded.keyBindings[0].quickTapTermMs == 200)
    }

    @Test("Effective values resolve per-key overrides over globals")
    func effectiveValues() {
        var config = DefaultConfiguration.make()
        config.quickTapTermMs = 100

        config.keyBindings[0].quickTapTermMs = 150

        #expect(config.effectiveQuickTapTerm(for: config.keyBindings[0]) == 150)
        #expect(config.effectiveQuickTapTerm(for: config.keyBindings[1]) == 100)
    }

    @Test("Binding lookup by keyCode works")
    func bindingLookup() {
        let config = DefaultConfiguration.make()
        let aBinding = config.binding(for: 0x00)
        #expect(aBinding?.label == "A")
        #expect(aBinding?.modifier == .control)

        // G is disabled by default
        let gBinding = config.binding(for: 0x05)
        #expect(gBinding == nil)
    }

    @Test("Default layout has correct modifier assignments")
    func defaultLayout() {
        let config = DefaultConfiguration.make()
        let bindings = config.keyBindings

        let a = bindings.first { $0.label == "A" }!
        let s = bindings.first { $0.label == "S" }!
        let d = bindings.first { $0.label == "D" }!
        let f = bindings.first { $0.label == "F" }!
        let j = bindings.first { $0.label == "J" }!
        let k = bindings.first { $0.label == "K" }!
        let l = bindings.first { $0.label == "L" }!
        let semi = bindings.first { $0.label == ";" }!

        #expect(a.modifier == .control)
        #expect(s.modifier == .option)
        #expect(d.modifier == .command)
        #expect(f.modifier == .shift)
        #expect(j.modifier == .shift)
        #expect(k.modifier == .command)
        #expect(l.modifier == .option)
        #expect(semi.modifier == .control)
    }
}
