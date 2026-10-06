import Foundation

/// Every line the helper writes, stamped, in one place.
///
/// launchd points the daemon's stderr at `/var/log/ewiz-helper.log` and adds nothing
/// of its own, so the file was four thousand bare sentences with no way to tell a wake
/// last night from a wake three months ago — and that file is exactly what you reach for
/// when someone asks why their Mac lost 6% overnight. "woke from sleep" a thousand times
/// answers nothing without the times beside it.
///
/// The prefix was also copy-pasted into five files, which is why some lines carried
/// `error:` and others reporting failures didn't.
enum HelperLog {
    /// Local time, not ISO-8601 with an offset: this log is read next to the Console and
    /// next to "it happened around midnight", and a UTC stamp makes the reader do arithmetic
    /// before they can start.
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    /// The tick loop, the accept thread and the sleep hook all log. Without this their
    /// writes interleave mid-line.
    private static let lock = NSLock()

    static func info(_ message: String) { write(message) }
    static func error(_ message: String) { write("error: \(message)") }

    private static func write(_ body: String) {
        lock.lock()
        defer { lock.unlock() }
        FileHandle.standardError.write(Data("\(stamp.string(from: Date())) ewiz-helper: \(body)\n".utf8))
    }
}
