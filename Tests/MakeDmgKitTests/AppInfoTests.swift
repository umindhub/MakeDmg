import Testing
@testable import MakeDmgKit

@Test func versionIsSet() {
    #expect(!AppInfo.version.isEmpty)
}
