import Foundation
import AppKit
import CoreAudio
import CoreGraphics
import IOKit
import IOBluetooth
import EWizKit

/// Reads the live system state the automation rules test against.
///
/// Every probe is opt-in: `probe(kinds:…)` only touches the sensors the enabled
/// rules actually reference, so a Mac with two simple rules never enumerates USB
/// or walks the audio graph. Individual probes are cheap (IORegistry / syscall
/// reads) and safe to run on the main thread at the poll interval.
enum TriggerSensors {

    /// Build a snapshot covering `kinds`. Battery values come from the store's
    /// existing IOKit read, so we never duplicate that work.
    @MainActor
    static func probe(kinds: Set<TriggerKind>,
                      battery: BatterySnapshot,
                      cpu: CPUSampler) -> TriggerSnapshot {
        var s = TriggerSnapshot()

        if kinds.contains(.externalDisplay) {
            s.externalDisplays = externalDisplayCount()
        }
        if kinds.contains(.usbDevice) {
            s.usbDevices = usbDeviceNames()
        }
        if kinds.contains(.bluetoothDevice) {
            s.bluetoothDevices = connectedBluetoothNames()
        }
        if kinds.contains(.appRunning) {
            s.runningApps = runningAppTokens()
        }
        if kinds.contains(.appFrontmost) {
            s.frontmostApp = frontmostAppTokens()
        }
        if kinds.contains(.charging) || kinds.contains(.acPower) || kinds.contains(.batteryAbove) {
            s.isCharging = battery.isCharging
            s.isPluggedIn = battery.isPluggedIn
            s.batteryPercent = battery.percentage
        }
        if kinds.contains(.ipAddress) || kinds.contains(.vpn) {
            let net = interfaceAddresses()
            s.ipAddresses = net.addresses
            s.vpnInterfaces = net.tunnels
        }
        if kinds.contains(.wifiNetwork) {
            s.ssid = RadioControl.currentSSID
        }
        if kinds.contains(.audioOutput) {
            let out = defaultAudioOutput()
            s.audioOutput = out.name
            s.audioOutputIsExternal = out.isExternal
        }
        if kinds.contains(.volumeMounted) {
            s.externalVolumes = externalVolumeNames()
        }
        if kinds.contains(.cpuAbove) {
            s.cpuPercent = cpu.sample()
        }
        return s
    }

    // MARK: - Displays

    /// Displays that aren't the built-in panel. Uses `CGDisplayIsBuiltin` rather
    /// than "screen count − 1" so it stays right in clamshell mode, where the
    /// built-in panel drops out of `NSScreen.screens` entirely.
    @MainActor
    static func externalDisplayCount() -> Int {
        NSScreen.screens.reduce(into: 0) { count, screen in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
            if CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0 { count += 1 }
        }
    }

    /// Names of the attached displays, for the picker.
    @MainActor
    static func externalDisplayNames() -> [String] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
            else { return nil }
            return screen.localizedName
        }
    }

    // MARK: - USB

    /// Product names of attached USB devices. Apple silicon exposes them as
    /// `IOUSBHostDevice`; Intel Macs use the older `IOUSBDevice` class, so both
    /// are matched and the results de-duplicated.
    static func usbDeviceNames() -> [String] {
        var names: [String] = []
        for className in ["IOUSBHostDevice", "IOUSBDevice"] {
            guard let matching = IOServiceMatching(className) else { continue }
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
                    == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }

            while case let service = IOIteratorNext(iterator), service != 0 {
                if let name = registryString(service, "USB Product Name")
                    ?? registryString(service, "Product Name")
                    ?? registryEntryName(service) {
                    names.append(name)
                }
                IOObjectRelease(service)
            }
        }
        return unique(names)
    }

    private static func registryString(_ service: io_service_t, _ key: String) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        else { return nil }
        return value as? String
    }

    private static func registryEntryName(_ service: io_service_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(service, &buffer) == KERN_SUCCESS else { return nil }
        let name = string(from: buffer)
        return name.isEmpty ? nil : name
    }

    /// A NUL-terminated C string in a fixed-size buffer, as a Swift `String`.
    private static func string(from buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    // MARK: - Bluetooth

    /// Paired Bluetooth devices that are connected right now (keyboard, mouse,
    /// headphones…). Returns [] when Bluetooth is off.
    static func connectedBluetoothNames() -> [String] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]
        else { return [] }
        return unique(paired.filter { $0.isConnected() }
            .compactMap { $0.name ?? $0.addressString })
    }

    // MARK: - Apps

    /// Lowercased names and bundle identifiers of every running app, so a rule
    /// can name either one.
    @MainActor
    static func runningAppTokens() -> [String] {
        NSWorkspace.shared.runningApplications.flatMap(tokens(for:))
    }

    @MainActor
    static func frontmostAppTokens() -> [String] {
        guard let app = NSWorkspace.shared.frontmostApplication else { return [] }
        return tokens(for: app)
    }

    private static func tokens(for app: NSRunningApplication) -> [String] {
        [app.localizedName, app.bundleIdentifier].compactMap { $0?.lowercased() }
    }

    /// User-facing apps (Dock-visible), for the app picker.
    @MainActor
    static func runningAppNames() -> [String] {
        unique(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.localizedName))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Network

    /// Routable addresses on every up, non-loopback interface, plus the names of
    /// tunnel interfaces that carry one.
    ///
    /// The tunnel list is how VPNs are detected: macOS keeps `utun` interfaces
    /// around for its own services (Private Relay, Handoff), but those only hold
    /// link-local addresses, which are filtered out here — so an interface still
    /// in the list is carrying real traffic.
    static func interfaceAddresses() -> (addresses: [String], tunnels: [String]) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return ([], []) }
        defer { freeifaddrs(head) }

        var addresses: [String] = []
        var tunnels: [String] = []

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let sockaddr = pointer.pointee.ifa_addr else { continue }
            let family = sockaddr.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sockaddr, socklen_t(sockaddr.pointee.sa_len),
                              &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }

            var address = string(from: host)
            if let zone = address.firstIndex(of: "%") { address = String(address[..<zone]) }
            // Link-local addresses mean "no real connectivity here".
            if address.hasPrefix("fe80") || address.hasPrefix("169.254") { continue }
            addresses.append(address)

            let name = String(cString: pointer.pointee.ifa_name)
            if ["utun", "ppp", "ipsec", "tun", "tap"].contains(where: name.hasPrefix) {
                tunnels.append(name)
            }
        }
        return (unique(addresses), unique(tunnels))
    }

    // MARK: - Audio

    /// The current default output device, and whether sound is going anywhere
    /// other than the built-in speakers.
    static func defaultAudioOutput() -> (name: String, isExternal: Bool) {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != AudioObjectID(kAudioObjectUnknown)
        else { return ("", false) }

        let name = audioDeviceName(deviceID)
        let transport = audioTransportType(deviceID)
        // The headphone jack reports as built-in hardware, so the data source is
        // what distinguishes plugged-in headphones from the speakers.
        let headphoneJack = audioDataSource(deviceID) == kAudioSourceHeadphones
        let isBuiltInSpeakers = transport == kAudioDeviceTransportTypeBuiltIn && !headphoneJack

        if headphoneJack { return ("Headphones", true) }
        return (name, !isBuiltInSpeakers)
    }

    /// `'hdpn'` — the built-in output's headphone data source.
    private static let kAudioSourceHeadphones: UInt32 = 0x6864_706E

    private static func audioDeviceName(_ device: AudioObjectID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        // CoreAudio hands back a retained CFStringRef, so take ownership of it.
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr,
              let value = name?.takeRetainedValue()
        else { return "" }
        return value as String
    }

    private static func audioTransportType(_ device: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport) == noErr
        else { return 0 }
        return transport
    }

    private static func audioDataSource(_ device: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var source = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &source) == noErr
        else { return 0 }
        return source
    }

    // MARK: - Volumes

    /// Mounted volumes that aren't on the internal disk — external drives, disk
    /// images, and network shares.
    static func externalVolumeNames() -> [String] {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIsInternalKey,
                                         .volumeIsBrowsableKey]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes])
        else { return [] }

        return unique(urls.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.volumeIsBrowsable != false,
                  values.volumeIsInternal != true,
                  let name = values.volumeName
            else { return nil }
            return name
        })
    }

    // MARK: - Utilities

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}

/// System-wide CPU utilization, measured as the delta in kernel tick counters
/// between calls. The first call has no baseline and reports 0.
@MainActor
final class CPUSampler {
    private var previous: host_cpu_load_info?
    private var last: Double = 0

    /// Percent busy (user + system + nice) since the previous call.
    func sample() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return last }
        defer { previous = info }
        guard let prev = previous else { return 0 }

        let user = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return last }

        last = min(100, (user + system + nice) / total * 100)
        return last
    }

    /// Drop the baseline so the next sample starts a fresh interval.
    func reset() { previous = nil }
}
