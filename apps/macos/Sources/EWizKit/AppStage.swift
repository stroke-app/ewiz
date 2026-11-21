import Foundation

/// eWiz is in beta until 1.0. Derived from the version rather than a flag, so the label
/// can't outlive the beta: shipping 1.0.0 is what takes it away.
public enum AppStage {
    public static func isBeta(version: String) -> Bool {
        let major = version.split(separator: ".").first.flatMap { Int($0) } ?? 0
        return major < 1
    }
}
