import Foundation
import IOKit.hid

/// Errors thrown by `HIDController`.
///
/// Descriptions are in English (the project's base language for source
/// text). The app layer is responsible for localizing user-facing copy;
/// see `docs/implementation-plan.md` for the localization strategy.
public enum HIDControllerError: Error, CustomStringConvertible {
    case managerOpenFailed(IOReturn)
    case deviceNotFound
    case notConnected
    case setReportFailed(IOReturn)

    public var description: String {
        switch self {
        case .managerOpenFailed(let result):
            return "Failed to open IOHIDManager (0x\(String(UInt32(bitPattern: result), radix: 16)))"
        case .deviceNotFound:
            return "radioSHARK 2 not found (check that it's connected and powered)"
        case .notConnected:
            return "Not connected to a device (call connect() first)"
        case .setReportFailed(let result):
            return "Failed to send HID report (0x\(String(UInt32(bitPattern: result), radix: 16)))"
        }
    }
}

/// radioSHARK 2 のHID（LED・チューナー制御）インターフェースへの薄いラッパー。
///
/// 現行の高レベルAPIである `IOHIDManager` を使う。歴史的なCLIツール
/// （`rslight`/`radiosh`）が使っている `IOCFPlugIn`/`IOHIDDeviceInterface**`
/// 方式は使わない（詳細は `docs/hardware-protocol.md` §3, §9）。
public final class HIDController {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?

    public init() {}

    /// radioSHARK 2（v2）を検索して接続する。
    /// 見つからない場合は `HIDControllerError.deviceNotFound` を投げる。
    public func connect() throws {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: DeviceIdentity.vendorID,
            kIOHIDProductIDKey as String: DeviceIdentity.productID,
            kIOHIDVersionNumberKey as String: DeviceIdentity.v2VersionNumber,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            throw HIDControllerError.managerOpenFailed(openResult)
        }

        guard
            let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
            let device = deviceSet.first
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw HIDControllerError.deviceNotFound
        }

        self.manager = manager
        self.device = device
    }

    /// 接続を閉じる。`deinit` からも呼ばれる。
    public func disconnect() {
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        device = nil
    }

    /// 青色LEDの輝度を設定する（0〜127）。
    public func setBlueLight(level: UInt8) throws {
        try send(HIDReports.blueLight(level: level))
    }

    /// 赤色LED（録音中インジケーター）の輝度を設定する（0〜127）。
    public func setRedLight(level: UInt8) throws {
        try send(HIDReports.redLight(level: level))
    }

    /// FM周波数（MHz）にチューニングする。
    public func tuneFM(megahertz: Double) throws {
        try send(HIDReports.fm(megahertz: megahertz))
    }

    /// AM周波数（kHz）にチューニングする。
    public func tuneAM(kilohertz: Int) throws {
        try send(HIDReports.am(kilohertz: kilohertz))
    }

    private func send(_ report: [UInt8]) throws {
        guard let device else { throw HIDControllerError.notConnected }
        var bytes = report
        let result = IOHIDDeviceSetReport(
            device, kIOHIDReportTypeOutput, 0, &bytes, bytes.count
        )
        guard result == kIOReturnSuccess else {
            throw HIDControllerError.setReportFailed(result)
        }
    }

    deinit {
        disconnect()
    }
}
