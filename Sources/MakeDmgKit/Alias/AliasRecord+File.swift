import Foundation

public enum AliasError: Error, Equatable, CustomStringConvertible {
    case statFailed(path: String, errno: Int32)
    case missingResourceValue(String)
    case notOnVolume(path: String, volume: String)

    public var description: String {
        switch self {
        case let .statFailed(path, code):
            return "cannot stat \(path): \(String(cString: strerror(code)))"
        case .missingResourceValue(let key):
            return "cannot read \(key) for alias"
        case let .notOnVolume(path, volume):
            return "\(path) is not inside volume \(volume)"
        }
    }
}

extension AliasRecord {
    /// Builds an alias from a file on a mounted volume. The file's parent must be a
    /// direct child of the volume root, which is how makedmg lays out .background.
    public static func forFile(at fileURL: URL, volumeURL: URL) throws -> AliasRecord {
        let file = fileURL.standardizedFileURL
        let volume = volumeURL.standardizedFileURL
        let parent = file.deletingLastPathComponent()

        let volumePath = volume.path.hasSuffix("/") ? String(volume.path.dropLast()) : volume.path
        guard file.path.hasPrefix(volumePath + "/") else {
            throw AliasError.notOnVolume(path: file.path, volume: volume.path)
        }

        let volumeValues = try volume.resourceValues(forKeys: [.volumeNameKey, .volumeCreationDateKey])
        guard let volumeName = volumeValues.volumeName else {
            throw AliasError.missingResourceValue("volume name")
        }
        guard let volumeDate = volumeValues.volumeCreationDate else {
            throw AliasError.missingResourceValue("volume creation date")
        }
        guard let fileDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate else {
            throw AliasError.missingResourceValue("file creation date")
        }

        let parentCNID = try fileID(parent)
        let fileCNID = try fileID(file)

        return AliasRecord(
            volumeName: volumeName,
            volumeCreationDate: volumeDate,
            parentCNID: parentCNID,
            parentName: parent.lastPathComponent,
            fileName: file.lastPathComponent,
            fileCNID: fileCNID,
            fileCreationDate: fileDate,
            pathInVolume: String(file.path.dropFirst(volumePath.count)),
            mountPoint: volumePath
        )
    }

    /// On HFS+ the inode number is the catalog node id.
    private static func fileID(_ url: URL) throws -> UInt32 {
        var info = stat()
        guard stat(url.path, &info) == 0 else {
            throw AliasError.statFailed(path: url.path, errno: errno)
        }
        return UInt32(truncatingIfNeeded: info.st_ino)
    }
}
