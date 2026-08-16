# radioSHARK 2 ハードウェア/プロトコル仕様

本ドキュメントは、Griffin Technology 製 USB ラジオチューナー「radioSHARK 2」を
macOS上で制御するために必要な低レベル仕様を、既存のオープンソース実装
（`rslight`, `radiosh`, `shark`, `shark2`）を解析してまとめたものである。

対象デバイスは **radioSHARK 2（v2）** のみとする。v1（初代 RadioSHARK）は
HIDレポート長・コマンド体系が異なるため、本プロジェクトではスコープ外とする
（将来的に対応する場合も、本書のv1関連の記載は移植の出発点として使える）。

## 1. デバイス概要

radioSHARKは2つの独立したUSB機能を1台のデバイスに持つ。

| 機能 | 実現方式 | macOS側の扱い |
|---|---|---|
| LED制御・チューナー選局 | USB HID（ベンダー定義レポート） | `IOKit` / `IOHIDDeviceInterface` で `setReport` |
| ラジオ音声の入力 | USB Audio Class 準拠のオーディオデバイス | 通常のUSBオーディオ入力として `CoreAudio` / `AVFoundation` から見える |

つまり、**音声キャプチャに関しては独自プロトコル実装は不要**で、
`AVAudioEngine` や `AVCaptureDevice` から通常のUSBマイク入力と同様に扱える。
一方、チューニングとLEDの制御は本書の独自プロトコルの実装が必須になる。

## 2. USB識別子

```
Vendor ID  : 0x077D
Product ID : 0x627A
```

`IOHIDVersionNumberKey` でハードウェア世代を判別する。

| 世代 | Version値 | HIDレポート長 |
|---|---|---|
| v1（RadioSHARK） | `0x0001` | 6 バイト |
| v2（radioSHARK 2） | `0x0010` | 7 バイト |

本プロジェクトは `0x0010`（v2）のみをマッチング対象にする。

## 3. デバイスの発見・接続（IOKit）

```
matchingDict = IOServiceMatching(kIOHIDDeviceKey)
matchingDict[kIOHIDVendorIDKey]      = 0x077D
matchingDict[kIOHIDProductIDKey]     = 0x627A
matchingDict[kIOHIDVersionNumberKey] = 0x0010          // v2固定

service = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict)
IOCreatePlugInInterfaceForService(service, kIOHIDDeviceUserClientTypeID, ...)
  -> QueryInterface(kIOHIDDeviceInterfaceID) で IOHIDDeviceInterface** を取得
  -> open()
  -> setReport(kIOHIDReportTypeOutput, ...) でレポート送信
```

抜き差し検知は `IOServiceAddMatchingNotification`
（`kIOMatchedNotification` / `kIOTerminatedNotification`）で行う。
ブックマークに残っていた次の資料が実装の参考になる：

- Qiita「Swift：macでUSBデバイスの接続/排出を検知する」
- `knightsc/USBApp`（Swiftでの IOKit 通知の実装例）
- 「SwiftにIOServiceMatchingCallBackを実装する方法」

## 4. HIDレポート仕様（v2 / 7バイト）

すべて `kIOHIDReportTypeOutput`、レポートID `0`、タイムアウト1000msで送信する。

### 4.1 青色LED（本体アイコンの明るさ）

```
[0] = 0x83
[1] = level        // 0（消灯）〜 127
[2..6] = 0x00
```

> v1にあった「青色LEDパルス速度」コマンド（`0xA1`）は **v2では未対応**。
> 既存実装（`radiosh.c`）でも `0xA1` / `0x82` を試した上で
> 「Oops: pulsing not supported on v2 devices.」とコメントされている。
> → マニュアルP.21の「radioSHARK light: On/Off/Pulse」設定のうち、
>   Pulseはv2実機で有効かどうか要検証（後述「未確定事項」）。

### 4.2 赤色LED（録音中インジケーター）

```
[0] = 0x84
[1] = level        // 0（消灯）〜 127
[2..6] = 0x00
```

マニュアル通り、アプリのFinアイコンは
「グレー＝未接続」「青＝接続」「赤＝接続＋録音中」で連動させる。

### 4.3 チューニング（選局）

```
[0] = 0x81
[1] = freqHi
[2] = freqLo
[3] = (band == FM) ? 0xF3 : 0x33
[4] = (band == FM) ? 0x36 : 0x04
[5] = 0x00
[6] = band          // AM: 0x24 / FM: 0x28
```

## 5. 周波数エンコード式（v2）

### FM（MHz指定）
```
raw = (MHz × 10 × 2) − 3
freqHi = (raw >> 8) & 0xFF
freqLo =  raw & 0xFF
band   = 0x28
```

### AM（kHz指定）
```
raw = (kHz × 4) + 16300
freqHi = (raw >> 8) & 0xFF
freqLo =  raw & 0xFF
band   = 0x24
```

`band` を負値（未指定）にした場合はチューニングコマンド自体を送らない
（＝現在の選局を変更しない）という挙動が既存実装の流儀。

## 6. チューニングレンジ・刻み幅（マニュアルP.20 Preferences – Tuning より）

アプリの環境設定として以下を持たせる（実際の刻み幅制御はホスト側で
「何MHz/kHzずつUp/Downさせるか」を管理し、都度上記エンコード式で
HIDレポートを送るだけでよい。デバイス側に範囲や刻みの概念はない）。

| 設定項目 | 選択肢 |
|---|---|
| FM Tuning range | Standard（87.5–107.9MHz） / Japanese（76–89MHz） |
| Tune which FM frequencies | Odd / Even / All（0.1MHz刻みの偶奇） |
| AM tuning increment | 9kHz / 10kHz |

## 7. 複数デバイス接続時の挙動

既存実装（`radiosh.c`）はv1を先に探し、見つからなければv2にフォールバックする
（v1優先）という簡易な仕様だった。本プロジェクトはv2専用のため、
複数のradioSHARK 2が接続された場合の挙動（先着1台のみ制御 or
デバイス選択UIを設ける）は別途要件として検討する（「未確定事項」参照）。

## 8. 音声入出力

- radioSHARK 2はUSB Audio Class準拠のデバイスとして列挙される
  （`arecord -l` でも一覧に出る＝Linuxの標準ALSAドライバだけで認識される、
  というKenKundert/radioshark リポジトリの実装からの傍証）。
- macOSでは特別なドライバ不要で、システム環境設定の「サウンド」入力デバイス
  一覧、および `AVCaptureDevice.DiscoverySession` / `AudioObjectID` から
  通常のUSBオーディオ入力として取得できる想定。
- ライブ再生・録音・タイムシフトはすべてホストアプリ側でアプリケーション層
  として実装する（`AVAudioEngine` の input node → 循環バッファ →
  output node / ファイル書き出し、という構成。詳細は
  `implementation-plan.md` の Phase 2 を参照）。

## 9. 参照した既存実装と出典

| ファイル | 作者 | ライセンス | 内容 |
|---|---|---|---|
| `rslight.c` | Quentin D. Carnicelli (Rogue Amoeba) | 明記なし（著者クレジットのみ） | v1のLED制御のみのCLI |
| `radiosh.c` | Cameron Kaiser（rslight / shark / shark2 のマージ版） | BSD風の再頒布許諾（要出典表示） | v1/v2 両対応、LED＋チューニング |
| `shark.c` / `shark2.c` | Michael Rolig, Justin Yunke, Hisaaki Shibata | `radiosh.c` に統合済み、個別確認は省略 | `radiosh.c` の前身 |
| `KenKundert/radioshark`（GitHub） | Ken Kundert | 要確認 | macOS版ではなくLinux/Python。ALSA経由の音声録音とスケジューリングの自動化スクリプト群。HID制御コードは含まれない |

> **ライセンスに関する注意**：`radiosh.c` はソースコードの再頒布条件
> （著作権表示・免責事項の保持）を明記したBSD類似ライセンスを持つ。
> 本プロジェクトでは **Cのコードをそのまま移植/コピーするのではなく**、
> 上記で文書化した「バイトレイアウト・周波数計算式」という
> **事実・仕様のみ**を参照してSwiftで独自実装する方針とする
> （事実・アルゴリズムの記述は著作権の対象外だが、コードの丸写しは
> 対象になりうるため）。README／NOTICEに出典として
> `rslight` (Quentin D. Carnicelli) と `radiosh`
> (Cameron Kaiser, floodgap.com) へのクレジットを明記すること。

## 10. 未確定事項（実機検証が必要な項目）

1. 青色LEDの「Pulse」モードがv2で本当に無効か（別のレポートIDの可能性）。**未検証**
2. ~~`IOHIDVersionNumberKey` によるマッチングが、実際のmacOS最新版でも期待通り機能するか~~
   → **2026-08-16 実機検証済み**。`bcdDevice = 16`（0x0010）としてv2実機が
   最新macOS（Darwin 25.6.0 / Sequoia以降相当）でも正しく認識されることを確認（§11参照）。
3. ~~USBオーディオとして認識された際のサンプルレート/チャンネル構成~~
   → **2026-08-16 実機検証済み**。`system_profiler SPAudioDataType` に
   単体の入力デバイス「radioSHARK」（Manufacturer: Griffin Technology, Inc.、
   Input Channels: 2、Current SampleRate: 48000Hz、Transport: USB）として
   ドライバ不要で認識されることを確認。
4. App Sandbox外・非sandboxedアプリからの `IOHIDManager` 経由アクセスが
   最新macOSのプライバシー/セキュリティ制限（TCCなど）に引っかからないか。
   → `hidutil list`（非sandboxed CLI）からは追加権限なしに参照できることを確認済みだが、
   自作アプリからの `open()`/`setReport()` 実行は**未検証**（Phase 1で確認する）。
5. 複数台接続時の挙動仕様。**未検証**（該当環境なし）

## 11. 実機検証ログ（2026-08-16）

`ioreg -l`（全プレーン）および `hidutil list` で実機を検出。本書の仕様が
実機の値と一致することを確認した。

```
USB Product Name : radioSHARK
USB Vendor Name  : Griffin Technology, Inc.
idVendor         : 1917   (0x077D)  … 本書§2の記載と一致
idProduct        : 25210  (0x627A)  … 本書§2の記載と一致
bcdDevice        : 16     (0x0010) … v2（本書§2の判定表と一致）
bcdUSB           : 272    (0x0110) … USB 1.1
USBSpeed         : Full Speed (12 Mbps)
```

USBコンポジット構成（3インターフェース）:

| Interface | bInterfaceClass | 用途 | 実機での担当ドライバ |
|---|---|---|---|
| @0 | 1 (Audio), SubClass 1 (Audio Control) | オーディオ制御 | `usbaudiod`（macOS標準） |
| @1 | 1 (Audio), SubClass 2 (Audio Streaming) | オーディオストリーム | `usbaudiod`（macOS標準） |
| @2 | 3 (HID), SubClass 0 | LED/チューナー制御 | `AppleUserUSBHostHIDDevice`（macOS標準HIDドライバ） |

- **音声**：`system_profiler SPAudioDataType` に単体の入力デバイス
  「radioSHARK」（2ch、48kHz、USB）として自動認識。追加ドライバ不要、
  §8の想定通り。
- **HID**：`MaxInputReportSize` / `MaxOutputReportSize` ともに **7バイト**、
  Report IDなし（`0`固定）。§4の7バイトレポート仕様と一致。
  HID Report Descriptorをデコードすると Usage Page = Consumer(0x0C)、
  Usage = 0x01 の1コレクションの中に7バイトのOutput/Inputフィールドが
  あるのみで、コマンド体系はホスト側アプリの取り決め（本書§4の
  `0x81`/`0x83`/`0x84`）に委ねられている（=ベンダー定義コマンドが
  Consumer Control usageの中に押し込まれている、古いHID機器にありがちな作り）。
- `hidutil list` で `0x77d`/`0x627a` のHIDデバイスとして参照可能なことを確認
  （非sandboxedのCLIから追加権限なしでアクセスできている）。

**トラブルシュートの教訓**：初回接続確認時（本ドキュメント作成直後）は
`ioreg`/`system_profiler`/`hidutil` のいずれにも一切現れなかった。
再接続後は正常に認識された。USB 1.1 Full Speedの旧機種のため、
ハブの相性やUSB列挙タイミングの問題で**認識に失敗することがある**点は
留意事項としてPhase 0のチェックリストに残す（`docs/implementation-plan.md`
の検証ログも参照）。
