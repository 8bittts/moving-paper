import Testing
import Foundation

/// Tests for the version bump logic used by build-dmg.sh.
/// Mirrors the bump_version() function: X.XXX format, +.001 per release.
struct VersionBumpTests {

    /// Replicates the bash bump_version function
    private func bumpVersion(_ current: String) -> String {
        let parts = current.split(separator: ".", maxSplits: 1)
        guard parts.count == 2,
              var major = Int(parts[0]),
              var minor = Int(parts[1]) else {
            return current
        }
        minor += 1
        if minor >= 1000 {
            major += 1
            minor = 1
        }
        return String(format: "%d.%03d", major, minor)
    }

    @Test func basicIncrement() {
        #expect(bumpVersion("0.001") == "0.002")
    }

    @Test func incrementAcrossTens() {
        #expect(bumpVersion("0.009") == "0.010")
    }

    @Test func incrementAcrossHundreds() {
        #expect(bumpVersion("0.099") == "0.100")
    }

    @Test func rolloverToNextMajor() {
        #expect(bumpVersion("0.999") == "1.001")
    }

    @Test func higherMajor() {
        #expect(bumpVersion("1.042") == "1.043")
    }

    @Test func majorRolloverFromHigher() {
        #expect(bumpVersion("2.999") == "3.001")
    }

    @Test func midRange() {
        #expect(bumpVersion("0.500") == "0.501")
    }
}
