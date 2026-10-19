import Foundation
import Testing
@testable import MakeDmgKit

@Suite struct ShellTests {
    @Test func capturesOutput() throws {
        let result = try Shell(logger: nil).run("/bin/echo", ["hello"])
        #expect(result.status == 0)
        #expect(result.stdout == "hello\n")
    }

    @Test func throwsOnFailure() {
        #expect(throws: ShellError.self) {
            try Shell(logger: nil).run("/bin/sh", ["-c", "echo boom >&2; exit 3"])
        }
    }

    @Test func allowFailureReturnsStatus() throws {
        let result = try Shell(logger: nil).run("/bin/sh", ["-c", "echo boom >&2; exit 3"], allowFailure: true)
        #expect(result.status == 3)
        #expect(result.output == "boom")
    }

    @Test func quotesOnlyWhenNeeded() {
        #expect(Shell.quote("/usr/bin/hdiutil") == "/usr/bin/hdiutil")
        #expect(Shell.quote("Developer ID Application: A (B)") == "'Developer ID Application: A (B)'")
        #expect(Shell.quote("it's") == "'it'\\''s'")
    }
}
