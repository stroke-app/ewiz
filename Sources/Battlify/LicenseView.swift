import SwiftUI
import BattlifyKit

struct LicenseView: View {
    @EnvironmentObject private var license: LicenseManager
    @State private var confirmingRemoval = false

    // Checkout page; mints an Ed25519 license key on purchase.
    private let buyURL = URL(string: "https://battlify.app/buy")!

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                // The app's own mark, as on the About tab, not a stock symbol.
                BatteryGlyph(percentage: 100, bolt: true,
                             color: Color(ChargePalette.legible(1)), width: 30)
                    .frame(width: 52, height: 52)
                    .background(.quaternary.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battlify").font(.title2.weight(.semibold))
                    Text(license.statusText).font(.callout).foregroundStyle(.secondary)
                }
            }

            Divider()

            if case .licensed(let name) = license.state {
                licensedView(name)
            } else {
                pricingView
                activationView
            }

            Divider()
            supportFooter
        }
        .padding(24)
        .frame(width: 440)
        // The window opens with the first button as first responder, and with Remove
        // License the only button that was the destructive one, ringed and a Space bar
        // away from firing. No ring, and removal now asks first anyway.
        .focusEffectDisabled()
        .confirmationDialog("Remove the license from this Mac?", isPresented: $confirmingRemoval) {
            Button("Remove License", role: .destructive) { license.deactivate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Battlify goes back to the trial, or locks if the trial is used up, until the key is entered again. Keep a copy of your key first.")
        }
    }

    // MARK: - Licensed

    @ViewBuilder
    private func licensedView(_ name: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3).foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Licensed to \(name)").font(.callout.weight(.semibold))
                Text("One-time purchase. Every feature is unlocked on this Mac, updates included.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        HStack {
            Spacer()
            // Small and plain: the way out of a purchase isn't the action this window is for.
            Button("Remove License…") { confirmingRemoval = true }
                .controlSize(.small)
        }
    }

    // MARK: - Support

    /// Lost keys, a key that won't take, a new Mac: the questions people actually write in
    /// with. The email carries the device code and app version, which is what answering
    /// any of them needs first.
    private var supportFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
            Text("Lost your key or moving to a new Mac?")
                .font(.caption).foregroundStyle(.secondary)
            Button("Contact Support") {
                let summary = "Battlify \(SupportInfo.version)\nmacOS \(ProcessInfo.processInfo.operatingSystemVersionString)\nLicense: \(license.statusText)"
                if let url = SupportInfo.emailURL(subject: "Battlify license", summary: summary,
                                                  extra: ["Device code: \(license.deviceCode)"]) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link).font(.caption)
        }
    }

    // MARK: - Pricing

    private var pricingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            pricePoint(icon: "gift", tint: .secondary, title: "Free for 30 days",
                       body: "Your free days are only used up when you actually use Battlify, so you get the most out of them, stress-free.")
            pricePoint(icon: "checkmark.seal", tint: .secondary, title: "$2.99 to own",
                       body: "One-time payment, no subscriptions. Quick checkout with Apple Pay.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func pricePoint(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Activation

    @ViewBuilder
    private var activationView: some View {
        if case .expired = license.state {
            Label("Your 30 free days are up. Buy Battlify to keep using its controls.",
                  systemImage: "exclamationmark.circle")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !license.deviceCode.isEmpty {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your device code. Enter it at checkout")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(license.deviceCode)
                        .font(.system(.callout, design: .monospaced).weight(.medium))
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(license.deviceCode, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }
            .padding(10)
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        VStack(alignment: .leading, spacing: 6) {
            Text("Already bought it? Enter your license key")
                .font(.caption).foregroundStyle(.secondary)
            TextField("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX",
                      text: $license.enteredKey, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .font(.system(.callout, design: .monospaced))
        }

        if let err = license.lastError {
            Label(err, systemImage: "xmark.octagon")
                .font(.caption).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }

        HStack {
            Link("Buy Battlify · $2.99", destination: buyURL)
                .font(.callout.weight(.medium))
            Spacer()
            // No progress spinner: `activate()` is offline Ed25519 verification and returns
            // in well under a frame. The `verifying` flag that gated one here was never set
            // by anything, so the spinner and the two disabled states were unreachable —
            // a loading phase the app doesn't have.
            Button("Activate") { license.activate() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
