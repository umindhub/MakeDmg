import MakeDmgKit

struct ConsoleBuildLogger: BuildLogger {
    let verbose: Bool

    func step(_ message: String) {
        Console.step(message)
    }

    func detail(_ message: String) {
        if verbose { Console.info("    \(message)") }
    }

    func warning(_ message: String) {
        Console.warning(message)
    }
}
