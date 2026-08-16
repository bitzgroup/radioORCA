# 実装計画

## 前提・決定事項

| 項目 | 決定内容 |
|---|---|
| 対応ハードウェア | radioSHARK **2（v2）専用**。v1は非対応（`docs/hardware-protocol.md` 参照） |
| 配布形態 | **無料**（寄付導線なし）。将来必要になれば別途検討 |
| 配布経路 | **GitHubパブリックリポジトリのReleasesページ**からdmgを直接ダウンロード。Mac App Storeは使わない |
| App Sandbox | **使用しない**（非サンドボックス）。USB HIDアクセスを素直に実装するため |
| 署名 | Developer ID Application証明書で署名 + `notarytool` で公証（Gatekeeperに引っかからないようにする） |
| ライセンス | MIT（リポジトリに設定済み）。プロトコル知識の出典は `hardware-protocol.md` §9 にクレジット記載 |
| アプリ名 | **radioORCA**（"radioSHARK"はGriffinの商標のため、対応ハードウェア名としての言及に留める） |
| 既存Xcodeプロジェクト | **参照しない**。`~/Documents/Development/Projects/radioORCA` の過去プロトタイプは白紙に戻し、本リポジトリ内に新規プロジェクトを作成する |
| UIフレームワーク | SwiftUI + Swift Concurrency（async/await, actor）。Swift 6 language mode を第一候補とする |
| デバイス制御API | **`IOHIDManager`**（現行の高レベルHID API）を採用。`rslight`/`radiosh` が使う古い `IOCFPlugIn` / `IOHIDDeviceInterface**` 方式は参照しない（プロトコル仕様＝バイト列の知識のみ流用） |
| テスト | Swift Testing（XCTestではなく新フレームワーク）を第一候補とする |
| 対応macOS | 最新2〜3世代を目安（要決定。下記「未決事項」参照） |

## アーキテクチャ概要

```
radioORCA (SwiftUI App, non-sandboxed, Developer ID署名)
├── RadioSharkKit/            … デバイス制御コアをSPMパッケージとして分離
│   ├── DeviceDiscovery       … IOKit HID接続監視 (attach/detach通知)
│   ├── HIDController         … setReportラッパー、LED/チューナーコマンド生成
│   ├── FrequencyCodec        … MHz/kHz ⇔ HIDバイト列 変換 (単体テスト重点)
│   └── AudioEngine           … AVAudioEngineでUSBオーディオ入力を取得・再生
├── App/                      … SwiftUI画面本体
│   ├── MainWindow             … チューニング/再生コントロール
│   ├── StationInfo            … お気に入り編集
│   ├── Schedule                … スケジュール録音
│   ├── Preferences             … 環境設定
│   └── Equalizer               … AVAudioUnitEQ操作UI
└── Resources/                … アイコン・アセット（独自デザイン、Griffin意匠の流用禁止）
```

`RadioSharkKit` をSPMパッケージとして分離するのは、
① ユニットテストしやすくする（特に周波数エンコード式）、
② 将来CLIツール（`rslight`/`radiosh`相当）を別ターゲットとして
同じコアで提供できるようにするため。

`HIDController` は `IOHIDManager`（`IOHIDManagerCreate` /
`IOHIDManagerSetDeviceMatching` / `IOHIDDeviceSetReport`）ベースで実装する。
`rslight.c` / `radiosh.c` が使っている `IOCreatePlugInInterfaceForService` +
`IOHIDDeviceInterface**` は10.5以前からある低レベルAPIで、現行では
`IOHIDManager` の方が簡潔かつ現行ドキュメントでも推奨される経路のため、
**コードではなくバイト列仕様のみ**を引き継いで実装し直す。

## フェーズ

### Phase 0. 実機検証・環境構築（着手前の土台作り）
- [ ] 実機がmacOSから認識されることを確認（`ioreg` / `system_profiler SPUSBDataType` /
      `hidutil list` でVendor ID `0x077D` を確認）。**現状：未検出、実機の物理接続を要再確認**
      （ハブ経由ではなく本体ポート直結を推奨。詳細は本ドキュメント末尾「検証ログ」参照）
- [ ] Vendor/Product/Version値を実機の値で最終確認
- [ ] **新規Xcodeプロジェクトを作成**（既存 `radioORCA` プロトタイプは参照しない）。
      アプリターゲット＋ローカルSPMパッケージ `RadioSharkKit` の構成にする
- [ ] Entitlementsは非サンドボックス構成（`app-sandbox`キーを付与しない）
- [ ] `docs/hardware-protocol.md` §10「未確定事項」のうち①②④を実機で検証

### Phase 1. RadioSharkKit：デバイス制御コア
- [ ] `DeviceDiscovery`：v2デバイスのマッチング辞書生成、接続/切断通知（`IOServiceAddMatchingNotification`）
- [ ] `HIDController`：open/close、`setBlueLight` / `setRedLight` / `setTuning` の実装
- [ ] `FrequencyCodec`：FM/AMのエンコード関数＋**単体テスト**（マニュアル記載の周波数レンジ境界値を含む）
- [ ] 手動テスト用の最小CLI（`swift run radiosh-cli -f 80.0` 等）でLED点灯・選局が実機で動くことを確認
  → ここまでで「コマンドラインで制御できる」state（ユーザーの既知の到達点）に**Swift版として追いつく**

### Phase 2. オーディオ（ライブ再生・録音・タイムシフト）
- [ ] `AVAudioEngine` でradioSHARKのUSBオーディオ入力デバイスを選択し、
      inputNode → outputNode 直結でライブモニタリング再生
- [ ] 録音：`AVAudioFile` でAAC(.m4a)書き出し、保存先 `~/Music/radioORCA/`
- [ ] タイムシフト：循環バッファ（既定10分、設定可能）実装。
      Rewind/Fast-Forward（可変速）、Skip Back/Ahead、Live復帰
- [ ] デバイス未接続時／切断時のハンドリング（UI上でUSBアイコン点滅相当の表示）

### Phase 3. メインUI（MVP機能）
- [ ] チューニングUI：Up/Down、AM/FM切替、スライダー、直接周波数入力、Tabシーク
- [ ] 再生コントロール：Volume、Mute、Record、Play/Pause、Live
- [ ] お気に入り（Favorites）＋プリセットキー（⌘+1〜9）
- [ ] Fin接続ステータス表示（グレー/青/赤）とLED実機連動
- [ ] `docs/app-feature-spec.md` §7 のショートカットキー一式を実装
- [ ] **この時点でMVPとして初回リリース候補**（β）

### Phase 4. スケジュール録音
- [ ] イベントモデル（繰り返し：Never/Daily/Weekly/Monthly/Yearly/Custom、終了条件：回数 or 日付）
- [ ] Scheduled/Recordedタブ相当のUI
- [ ] バックグラウンド実行方式の決定（アプリ常駐＋タイマー を第一候補。
      LaunchAgentでの完全バックグラウンド化はPhase 6以降で検討）

### Phase 5. 環境設定・EQ・仕上げ
- [ ] Preferences（録音フォーマット/画質、タイムシフトバッファ長、
      チューニングレンジ US/JP、AM刻み、LED表示モード）
- [ ] `AVAudioUnitEQ` による10バンドEQ＋プリセット
- [ ] Music.app連携は「自動追加」ではなく「保存先フォルダをFinderで開く」程度に留める案
      （二重コピー問題の回避。要ユーザー判断）

### Phase 6. 配布パイプライン
- [ ] Developer ID証明書取得、コード署名スクリプト
- [ ] `notarytool` による公証＋ステープル自動化
- [ ] GitHub Actions：タグpushで dmg をビルド → 署名 → 公証 → GitHub Releaseに添付
- [ ] リリースノート運用ルールの整備
- [ ] README整備：インストール手順、対応ハードウェア（v2のみである旨）、出典クレジット

## 未決事項（着手前 or 途中で決めるべきこと）

1. **対応macOS最低バージョン**：AVAudioEngine/SwiftUIの機能次第だが、
   古いUSB Audio 1.0デバイスの認識実績を優先するなら少し古めのOSも
   検証範囲に含めたい。ユーザーの利用環境（現在動かなくなった環境）に
   合わせて決定する。
2. **バックグラウンド予約録音の方式**：アプリを起動しっぱなしにする前提か、
   LaunchAgent的に常駐させるかで実装コストが変わる。MVPでは
   「アプリ起動中のみスケジュール実行」から始め、必要なら拡張する。
3. **複数デバイス接続時の挙動**（`hardware-protocol.md` §7）。
4. **青色LEDのPulseモード**がv2で実際に使えるか（Phase 0で検証）。

## マイルストーン目安

| マイルストーン | 内容 |
|---|---|
| M1 | Phase 0-1完了：SwiftでLED点灯・選局がCLIから実機動作 |
| M2 | Phase 2完了：ライブ再生・録音・タイムシフトが動作 |
| M3 | Phase 3完了：**MVPとして初回β公開（GitHub Releases）** |
| M4 | Phase 4-5完了：スケジュール録音・EQ・設定画面が揃う |
| M5 | Phase 6完了：署名・公証済みの正式1.0リリース（無料公開） |

## 検証ログ

### 2026-08-16：実機接続確認（1回目）

`ioreg -l`（全プレーン）、`system_profiler SPUSBDataType -detailLevel full`、
`hidutil list` でVendor ID `0x077D`（1917）/ Product ID `0x627A`（25210）を
持つデバイスを網羅的に検索したが、**該当デバイスは検出されなかった**。

接続中の外部USBデバイス一覧（参考）：
- VIA Labs USB3.0/USB2.0ハブ、Generic 4-Port USB2.0/3.0ハブ
- Logitec `LDR USB Device`
- EIZO `USB HID Monitor`
- `USB AUDIO  CODEC`（Texas Instruments, idVendor=0x08BB/2235）
  → **radioSHARKではない別デバイス**（Vendor IDが不一致）
- ASMT `CRTS35U32C`（USB-SATAブリッジ）
- Logitech `HD Pro Webcam C920`
- Bluetooth Magic Keyboard

**次のアクション**：ハブ経由ではなくMac本体のポートに直結する等、
物理接続を再確認の上、再検証する。

### 2026-08-16：実機接続確認（2回目・成功）

再接続後、`ioreg` / `hidutil list` の両方で radioSHARK 2 実機を検出。

- `idVendor=1917(0x077D)` / `idProduct=25210(0x627A)` / `bcdDevice=16(0x0010=v2)`
  … `docs/hardware-protocol.md` の仕様と完全一致
- HIDレポートは `MaxInputReportSize=MaxOutputReportSize=7`（v2の7バイト仕様と一致）
- オーディオは `system_profiler SPAudioDataType` に「radioSHARK」
  （2ch/48kHz/USB）として追加ドライバなしで認識
- `hidutil list` で `0x77d`/`0x627a` のHIDデバイスとして参照可能
  （非sandboxedのCLIから追加権限なしにアクセス可能なことを確認）

詳細は `docs/hardware-protocol.md` §11「実機検証ログ」を参照。

**教訓**：1回目に未検出だったのは、USB 1.1 Full Speedの旧機種特有の
ハブ相性 or 列挙タイミングの問題と思われる。**Phase 0では実機接続を
Mac本体ポート直結でまず試す**運用を前提にする。
