import Foundation

/// Every address the app sends people to, in one place.
///
/// The website is ewiz.app, and each `ewiz.app` path below is a page it has to serve.
/// DISTRIBUTION.md lists them with what each one does; keep the two in step.
public enum EWizLinks {
    /// The home page: Settings › About › Visit the Website.
    public static let website = URL(string: "https://ewiz.app")!

    /// Checkout. Takes the buyer's device code (shown in the license window) and emails a
    /// key signed for that code. See `License` for the key format.
    public static let buy = URL(string: "https://ewiz.app/buy")!

    /// Find a lost key, or get one issued for a new Mac or re-issued for an old unbound
    /// one. The license window and the "isn't linked to a Mac" error send people here.
    public static let license = URL(string: "https://ewiz.app/license")!

    /// Settings › About › Donate.
    public static let donate = URL(string: "https://ewiz.app/donate")!

    /// Where Contact Support and the license window's help link write to.
    public static let supportEmail = "hello@ewiz.app"

    /// Source and issues stay on GitHub.
    public static let source = URL(string: "https://github.com/stroke-app/ewiz")!
    public static let newIssue = URL(string: "https://github.com/stroke-app/ewiz/issues/new")!

    /// The update feed. On GitHub rather than the website: CI publishes it on every
    /// release, and installs from before the rename still read it at its old address.
    public static let updateFeed =
        URL(string: "https://raw.githubusercontent.com/stroke-app/ewiz-releases/main/appcast.json")!
}
