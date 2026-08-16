/// radioSHARK 2 のHIDチューニングレポートで使うバンド指定バイト。
public enum Band: UInt8, Sendable {
    case am = 0x24
    case fm = 0x28
}

/// AM/FM周波数 ⇔ radioSHARK 2 のHIDレポート用バイト列（`hi`/`lo`）の変換。
///
/// エンコード式の出典は `docs/hardware-protocol.md` §5。ハードウェアには
/// レンジや刻み幅の概念はなく、ホスト側で計算した生の周波数値を
/// 2バイトのビッグエンディアンで渡すだけでよい。
public enum FrequencyCodec {
    /// FM周波数（MHz）をエンコードする。例: `87.5` → 87.5MHz。
    public static func encodeFM(megahertz: Double) -> (hi: UInt8, lo: UInt8) {
        let raw = Int((megahertz * 10 * 2).rounded()) - 3
        return split(raw)
    }

    /// AM周波数（kHz）をエンコードする。例: `1710` → 1710kHz。
    public static func encodeAM(kilohertz: Int) -> (hi: UInt8, lo: UInt8) {
        let raw = (kilohertz * 4) + 16300
        return split(raw)
    }

    private static func split(_ raw: Int) -> (hi: UInt8, lo: UInt8) {
        let clamped = max(0, min(raw, 0xFFFF))
        return (UInt8((clamped >> 8) & 0xFF), UInt8(clamped & 0xFF))
    }
}
