import Foundation

/// On-disk cache of friends' profile photos so `fetchFriends` doesn't download every
/// CKAsset on every refresh.
///
/// Entries are keyed by the UserProfile record's `modificationDate`. Records carry no
/// image hash, so any change to the record invalidates the photo; owners only save
/// their profile when a field actually changes, which keeps that rare.
enum ProfileImageCache {
    private static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FriendProfileImages", isDirectory: true)
    }

    /// Cached photo data for `userID` at `modificationDate`. A cached "no photo" is
    /// returned as `.some(nil)`; a cache miss is `nil`.
    static func image(for userID: String, modifiedAt modificationDate: Date) -> Data?? {
        let url = fileURL(for: userID, modifiedAt: modificationDate)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return .some(data.isEmpty ? nil : data)
    }

    /// Stores `data` (nil = friend has no photo) and removes older entries for the user.
    static func store(_ data: Data?, for userID: String, modifiedAt modificationDate: Date) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let prefix = filePrefix(for: userID)
        let current = fileURL(for: userID, modifiedAt: modificationDate)
        if let existing = try? fileManager.contentsOfDirectory(atPath: directory.path) {
            for name in existing where name.hasPrefix(prefix) && name != current.lastPathComponent {
                try? fileManager.removeItem(at: directory.appendingPathComponent(name))
            }
        }
        try? (data ?? Data()).write(to: current, options: .atomic)
    }

    private static func filePrefix(for userID: String) -> String {
        // Apple user IDs are [0-9a-f.]; strip anything else so it's always a safe filename.
        let safe = userID.filter { $0.isLetter || $0.isNumber || $0 == "." }
        return "\(safe)_"
    }

    private static func fileURL(for userID: String, modifiedAt modificationDate: Date) -> URL {
        let stamp = Int64(modificationDate.timeIntervalSince1970 * 1000)
        return directory.appendingPathComponent("\(filePrefix(for: userID))\(stamp).jpg")
    }
}
