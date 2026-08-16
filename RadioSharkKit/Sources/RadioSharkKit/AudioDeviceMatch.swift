import CoreAudio

/// Locates the radioSHARK 2's USB Audio Class input device via CoreAudio.
///
/// This is independent of `DeviceIdentity` (the HID vendor/product IDs):
/// audio and HID are separate USB interfaces on the same composite device
/// (`docs/hardware-protocol.md` §8/§11), and CoreAudio doesn't expose USB
/// vendor/product IDs directly — matching is by device name instead.
public enum AudioDeviceMatch {
    /// The audio device name radioSHARK 2 reports, confirmed via
    /// `system_profiler SPAudioDataType` on real hardware
    /// (`docs/hardware-protocol.md` §11).
    public static let expectedDeviceName = "radioSHARK"

    /// Pure predicate, separated from the CoreAudio query below so it's
    /// unit testable without real audio hardware.
    public static func matches(deviceName: String) -> Bool {
        deviceName == expectedDeviceName
    }

    public enum DiscoveryError: Error, CustomStringConvertible {
        case queryFailed(OSStatus)
        case deviceNotFound

        public var description: String {
            switch self {
            case .queryFailed(let status):
                return "CoreAudio device query failed (status \(status))"
            case .deviceNotFound:
                return "radioSHARK audio input not found (check that it's connected)"
            }
        }
    }

    /// Searches all currently-known CoreAudio devices for one named
    /// "radioSHARK" and returns its `AudioDeviceID`.
    public static func findDeviceID() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        guard status == noErr else { throw DiscoveryError.queryFailed(status) }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { throw DiscoveryError.queryFailed(status) }

        for deviceID in deviceIDs {
            if let name = deviceName(of: deviceID), matches(deviceName: name) {
                return deviceID
            }
        }
        throw DiscoveryError.deviceNotFound
    }

    private static func deviceName(of deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }
}
