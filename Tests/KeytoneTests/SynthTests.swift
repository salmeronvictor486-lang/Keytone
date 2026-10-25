import XCTest
@testable import KeytoneCore

final class SynthTests: XCTestCase {
    func testEveryProfileRendersUsableSounds() {
        for profile in SwitchProfile.all {
            for kind in KeyKind.allCases {
                let press = SwitchSynth.render(profile, kind: kind, phase: .press, variant: 0)
                XCTAssertFalse(press.isEmpty, "\(profile.id) \(kind) sin sonido")
                XCTAssertLessThanOrEqual(DSP.peak(press), 1.0, "\(profile.id) \(kind) satura")
                XCTAssertGreaterThan(DSP.peak(press), 0.1, "\(profile.id) \(kind) casi inaudible")
                XCTAssertLessThan(press.count, Int(SwitchSynth.sampleRate * 2.2), "\(profile.id) \(kind) demasiado largo")
                XCTAssertFalse(press.contains { !$0.isFinite }, "\(profile.id) \(kind) con NaN")
            }
        }
    }

    func testRenderingIsDeterministic() {
        let profile = SwitchProfile.all[0]
        let a = SwitchSynth.render(profile, kind: .normal, phase: .press, variant: 3)
        let b = SwitchSynth.render(profile, kind: .normal, phase: .press, variant: 3)
        XCTAssertEqual(a, b)
    }

    func testVariantsAreDifferent() {
        let profile = SwitchProfile.all[0]
        let a = SwitchSynth.render(profile, kind: .normal, phase: .press, variant: 0)
        let b = SwitchSynth.render(profile, kind: .normal, phase: .press, variant: 1)
        XCTAssertNotEqual(a, b)
    }

    func testReleaseIsQuieterThanPress() {
        let profile = SwitchProfile.named("mx-brown")!
        let press = SwitchSynth.render(profile, kind: .normal, phase: .press, variant: 0)
        let release = SwitchSynth.render(profile, kind: .normal, phase: .release, variant: 0)
        XCTAssertLessThan(DSP.peak(release), DSP.peak(press))
    }

    func testProfileIDsAreUnique() {
        let ids = SwitchProfile.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testBankFallsBackToNormalKeys() {
        let bank = SoundBank(name: "test")
        bank.add([0.5, 0.2], kind: .normal, phase: .press)
        XCTAssertNotNil(bank.sample(keyCode: KeyLayout.space, kind: .space, phase: .press))
        XCTAssertNil(bank.sample(keyCode: 0, kind: .normal, phase: .release))
        XCTAssertNil(bank.sample(keyCode: 0, kind: .mouse, phase: .press))
    }

    func testBankPrefersPerKeySamples() {
        let bank = SoundBank(name: "test")
        bank.add([0.1], kind: .normal, phase: .press)
        bank.set([0.9], keyCode: 12, phase: .press)
        XCTAssertEqual(bank.sample(keyCode: 12, kind: .normal, phase: .press), [0.9])
    }

    func testKeyLayout() {
        XCTAssertEqual(KeyLayout.kind(for: 49), .space)
        XCTAssertEqual(KeyLayout.kind(for: 36), .enter)
        XCTAssertEqual(KeyLayout.kind(for: 51), .backspace)
        XCTAssertEqual(KeyLayout.kind(for: 56), .modifier)
        XCTAssertEqual(KeyLayout.kind(for: 0), .normal)
        XCTAssertLessThan(KeyLayout.horizontalPosition(for: 0), KeyLayout.horizontalPosition(for: 37))
        for code in UInt16(0)..<128 {
            let x = KeyLayout.horizontalPosition(for: code)
            XCTAssert((0...1).contains(x))
        }
    }

    func testResample() {
        let input = (0..<100).map { Float($0) }
        XCTAssertEqual(DSP.resample(input, rate: 2).count, 49)
        XCTAssertEqual(DSP.resample(input, rate: 1), input)
    }
}

final class MechvibesTests: XCTestCase {
    func testParsesSingleFilePack() throws {
        let json = """
        {"id":"x","name":"Cherry Test","key_define_type":"single","sound":"sound.ogg",
         "defines":{"1":[0,120],"57":[200,150],"28-up":[400,80],"999":[0,10]}}
        """
        let config = try JSONDecoder().decode(MechvibesConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.name, "Cherry Test")
        XCTAssertEqual(config.type, .single)
        XCTAssertEqual(config.sound, "sound.ogg")
        XCTAssertEqual(config.defines.count, 4)
        if case let .slice(start, duration)? = config.defines["57"] {
            XCTAssertEqual(start, 200)
            XCTAssertEqual(duration, 150)
        } else {
            XCTFail("57 debería ser un fragmento")
        }
    }

    func testParsesMultiFilePackWithNulls() throws {
        let json = """
        {"name":"Multi","key_define_type":"multi","defines":{"30":"a.wav","31":null,"14":"back.wav"}}
        """
        let config = try JSONDecoder().decode(MechvibesConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.type, .multi)
        XCTAssertEqual(config.defines.count, 2)
    }

    func testResolvesKeyCodes() {
        XCTAssertEqual(MechvibesConfig.resolve("57")?.keyCode, 49)
        XCTAssertEqual(MechvibesConfig.resolve("57")?.phase, .press)
        XCTAssertEqual(MechvibesConfig.resolve("28-up")?.keyCode, 36)
        XCTAssertEqual(MechvibesConfig.resolve("28-up")?.phase, .release)
        XCTAssertEqual(MechvibesConfig.resolve("30")?.keyCode, 0)
        XCTAssertNil(MechvibesConfig.resolve("999"))
    }
}
