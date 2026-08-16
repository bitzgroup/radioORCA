/// radioSHARK 2 のUSB識別子。
///
/// 仕様の出典と実機検証結果は `docs/hardware-protocol.md` を参照。
/// 本プロジェクトは radioSHARK **2（v2）専用**で、v1（初代 RadioSHARK）は
/// HIDレポート長・コマンド体系が異なるため対象外。
public enum DeviceIdentity {
    /// Griffin Technology, Inc.
    public static let vendorID: Int = 0x077D

    /// "radioSHARK"
    public static let productID: Int = 0x627A

    /// `kIOHIDVersionNumberKey` の値。v1は `0x0001`、v2は `0x0010`。
    public static let v2VersionNumber: Int = 0x0010
}
