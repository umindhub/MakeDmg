import ArgumentParser
import Foundation
import MakeDmgKit

struct InspectCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "inspect",
            abstract: "Print the Finder layout of a .dmg or a .DS_Store file.",
            discussion: "A .dmg is mounted read-only without Finder, inspected, then detached."
        )
    }

    @Argument(help: "Path to a .dmg or a .DS_Store file.")
    var path: String

    func run() throws {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        do {
            if url.pathExtension.lowercased() == "dmg" {
                try DiskImage.withMounted(url) { mount in
                    let name = (try? mount.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? mount.lastPathComponent
                    print("volume: \(name)\n")
                    printListing(of: mount)
                    print("")
                    try printRecords(at: mount.appendingPathComponent(".DS_Store"))
                }
            } else {
                try printRecords(at: url)
            }
        } catch {
            Console.error("\(url.path): \(error)")
            throw ExitCode.failure
        }
    }

    // MARK: - Volume listing

    private func printListing(of volume: URL) {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: volume.path)) ?? []).sorted()
        print("root entries:")
        for name in names {
            let itemPath = volume.appendingPathComponent(name).path
            var info = stat()
            guard lstat(itemPath, &info) == 0 else { continue }

            var kind = (info.st_mode & S_IFMT) == S_IFDIR ? "dir " : "file"
            var suffix = ""
            if (info.st_mode & S_IFMT) == S_IFLNK {
                kind = "link"
                let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: itemPath)) ?? "?"
                suffix = " -> \(target)"
            }
            let hidden = info.st_flags & UInt32(UF_HIDDEN) != 0 ? "  [hidden]" : ""
            print("  \(kind)  \(name)\(suffix)\(hidden)")
        }
    }

    // MARK: - Records

    private func printRecords(at url: URL) throws {
        let records = try DSStoreReader.read(contentsOf: url)
        print(".DS_Store records:")
        for record in records {
            let name = record.filename == "." ? ". (volume root)" : record.filename
            print("  \(name)  \(record.code)  \(describe(record))")
        }
    }

    private func describe(_ record: DSStoreRecord) -> String {
        switch record.value {
        case .long(let v): return "long \(v)"
        case .shor(let v): return "shor \(v)"
        case .bool(let v): return "bool \(v)"
        case .type(let v): return "type \(v)"
        case .ustr(let v): return "ustr \"\(v)\""
        case .comp(let v): return "comp \(v)"
        case .dutc(let v): return "dutc \(v)"
        case .blob(let data): return describeBlob(data, code: record.code)
        }
    }

    private func describeBlob(_ data: Data, code: FourCC) -> String {
        let bytes = [UInt8](data)
        if code == "Iloc", bytes.count >= 8 {
            let x = Int32(bitPattern: bytes[0..<4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
            let y = Int32(bitPattern: bytes[4..<8].reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
            return "x=\(x) y=\(y)"
        }
        if bytes.starts(with: Array("bplist".utf8)),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            let lines = plist.keys.sorted().map { key in
                "      \(key) = \(describePlistValue(plist[key]!))"
            }
            return "plist\n" + lines.joined(separator: "\n")
        }
        if bytes.count <= 32 {
            return "blob " + bytes.map { String(format: "%02x", Int($0)) }.joined(separator: " ")
        }
        return "blob <\(bytes.count) bytes>"
    }

    private func describePlistValue(_ value: Any) -> String {
        if let data = value as? Data { return "<\(data.count) bytes>" }
        if let string = value as? String { return "\"\(string)\"" }
        return String(describing: value)
    }
}
