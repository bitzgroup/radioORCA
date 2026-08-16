import Foundation
import IOKit.hid

/// radioSHARK 2 の接続・切断を監視する。
///
/// `IOHIDManagerRegisterDeviceMatchingCallback` / `...RemovalCallback` を
/// メインランループ上でスケジュールして使う（アプリのメインスレッドで
/// `start()` を呼ぶことを想定）。
public final class DeviceDiscovery {
    /// デバイスが接続されたときに呼ばれる。
    public var onConnect: (() -> Void)?
    /// デバイスが切断されたときに呼ばれる。
    public var onDisconnect: (() -> Void)?

    private var manager: IOHIDManager?

    public init() {}

    /// 監視を開始する。カレントランループ（通常はメインランループ）に
    /// スケジュールされる。
    public func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: DeviceIdentity.vendorID,
            kIOHIDProductIDKey as String: DeviceIdentity.productID,
            kIOHIDVersionNumberKey as String: DeviceIdentity.v2VersionNumber,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, _, _, _ in
                guard let context else { return }
                Unmanaged<DeviceDiscovery>.fromOpaque(context).takeUnretainedValue().onConnect?()
            },
            context
        )

        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, _, _, _ in
                guard let context else { return }
                Unmanaged<DeviceDiscovery>.fromOpaque(context).takeUnretainedValue().onDisconnect?()
            },
            context
        )

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        self.manager = manager
    }

    /// 監視を停止する。
    public func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    deinit { stop() }
}
