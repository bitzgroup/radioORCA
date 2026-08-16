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
| リポジトリ名 | **`bitzgroup/radioORCA`**（2026-08-16に`bitzgroup/radioSHARK`から改名済み。アプリ名と統一） |
| 既存Xcodeプロジェクト | **参照しない**。`~/Documents/Development/Projects/radioORCA` の過去プロトタイプは白紙に戻し、本リポジトリ内に新規プロジェクトを作成する |
| UIフレームワーク | SwiftUI + Swift Concurrency（async/await, actor）。Swift 6 language mode を第一候補とする |
| デバイス制御API | **`IOHIDManager`**（現行の高レベルHID API）を採用。`rslight`/`radiosh` が使う古い `IOCFPlugIn` / `IOHIDDeviceInterface**` 方式は参照しない（プロトコル仕様＝バイト列の知識のみ流用） |
| テスト | Swift Testing（XCTestではなく新フレームワーク）を第一候補とする |
| 対応macOS | 最新2〜3世代を目安（要決定。下記「未決事項」参照） |
| 言語（コード内文字列） | **英語をベース言語**とし、日本語はXcodeの String Catalog（`Localizable.xcstrings`）でローカライズ提供する。`docs/`配下のドキュメントは引き続き日本語（別の話） |

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

### Phase 0. 実機検証・環境構築（着手前の土台作り） — ✅ 完了（2026-08-16）
- [x] 実機がmacOSから認識されることを確認（`ioreg` / `hidutil list` でVendor ID
      `0x077D` を確認）。詳細は本ドキュメント末尾「検証ログ」参照
- [x] Vendor/Product/Version値を実機の値で最終確認（`idVendor=1917`,
      `idProduct=25210`, `bcdDevice=16` = v2）
- [x] **新規Xcodeプロジェクトを作成**（既存 `radioORCA` プロトタイプは参照していない）。
      `xcodegen`（`project.yml`）でアプリターゲット `radioORCA` を生成し、
      ローカルSPMパッケージ `RadioSharkKit` を依存として追加
- [x] Entitlementsは非サンドボックス構成（`app-sandbox`キーは付与していない。
      `project.yml` にコメントで明記）
- [x] `docs/hardware-protocol.md` §10「未確定事項」のうち②③④を実機で検証済み
      （①青色LED Pulse、⑤複数台接続は引き続き未検証）

### Phase 1. RadioSharkKit：デバイス制御コア — ✅ 主要部分完了（2026-08-16）
- [x] `DeviceDiscovery`：v2デバイスのマッチング辞書生成、接続/切断通知
      （`IOHIDManagerRegisterDeviceMatchingCallback`/`...RemovalCallback`を使用。
      当初案の`IOServiceAddMatchingNotification`ではなく`IOHIDManager`の
      コールバックAPIに統一）
- [x] `HIDController`：`IOHIDManager`ベースでopen/close、`setBlueLight` /
      `setRedLight` / `tuneFM` / `tuneAM` を実装
- [x] `FrequencyCodec` / `HIDReports`：FM/AMのエンコード関数＋**単体テスト**
      （Swift Testing、6テスト全通過）
- [x] 手動テスト用の最小CLI `radiosh-cli`（`swift run radiosh-cli -f 80.0 -b 100` 等）で
      実機のLED点灯・選局が動作することを確認
  → **「コマンドラインで制御できる」state（ユーザーの既知の到達点）にSwift版として到達（M1達成）**
- [ ] `DeviceDiscovery`をアプリ本体（SwiftUI）に組み込んで接続/切断UIに反映（Phase 3で対応）

### Phase 2. オーディオ（ライブ再生・録音・タイムシフト） — ✅ コア実装・実機検証完了（2026-08-16）
- [x] `AVAudioEngine` でradioSHARKのUSBオーディオ入力デバイスを選択し、
      ライブモニタリング再生を実装。**ただし「inputNode → outputNode 直結」
      という当初案は実機検証の結果不可能と判明**（radioSHARKがOutput
      Channelsを持たない入力専用デバイスのため。詳細は
      `hardware-protocol.md` §8）。キャプチャ専用エンジン（radioSHARK）と
      再生専用エンジン（既定の出力デバイス）を分離し、`AVAudioPlayerNode`
      経由でバッファを転送する構成に変更して実装（`AudioEngineController`）。
      実機でAMにチューニングした状態でのライブ再生（スピーカーからの音声）
      をユーザーが目視ならぬ耳で確認済み
- [x] 録音：`AVAudioFile`でAAC(.m4a)書き出し、保存先`~/Music/radioORCA/`
      （`RecordingSession`）。実機で5秒録音→`afinfo`で
      2ch/48kHz/AAC/約5.0秒のファイルが生成されることを確認済み
- [x] タイムシフト：循環バッファ（`RingBuffer`/`TimeshiftBuffer`、既定10分・
      `capacityMinutes`で設定可能）と、Rewind/Fast-Forward（連打で段階的に
      加速する可変速）/Skip Back・Ahead/Live復帰の状態機械
      （`TimeshiftPlaybackController`）を実装。**いずれも純粋ロジックとして
      ユニットテスト済み**（Swift Testing、19テスト追加）。ただし
      `AudioEngineController`側の実際のスクラブ再生（`AVAudioPlayerNode`
      へのスニペットスケジューリング）は実機での聴感確認は未実施
      （操作用UIがまだ無いため。Phase 3でUIを繋いだ際に確認する）。
      Rewindは「逆再生」ではなく「読み出し位置を過去へ移動しながら
      短いスニペットを順再生」という簡易実装（詳細は
      `TimeshiftPlaybackController`のドキュメントコメント参照。
      プロダクトフィードバック次第で見直す前提の一次実装）
- [x] デバイス未接続時／切断時のハンドリング：`AudioEngineController`が
      `connectionState`/`onConnectionStateChange`を公開し、
      `observe(_:DeviceDiscovery)`で接続/切断に連動して自動start/stopできる
      ようにした。**UI上の表示（USBアイコン点滅相当）はPhase 3で対応**
      （`DeviceDiscovery`のアプリ本体への組み込み自体もPhase 3待ち。
      Phase 1の未了項目と合流）

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
| M1 | ✅ **達成（2026-08-16）** Phase 0-1完了：SwiftでLED点灯・選局がCLIから実機動作 |
| M2 | ✅ **コア部分達成（2026-08-16）** Phase 2：ライブ再生・録音を実機確認。タイムシフトの実機聴感確認とPhase 1未了のUI組み込みはPhase 3待ち |
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

### 2026-08-16：Phase 0-1 実装・実機動作確認（成功）

`xcodegen`（`project.yml`）でXcodeプロジェクト `radioORCA.xcodeproj` を新規生成し、
`RadioSharkKit` ローカルSPMパッケージを実装。以下を実施・確認した。

- `swift build` / `swift test`（Swift Testing、6テスト）が通過
- 実機接続状態で `swift run radiosh-cli -b 40` / `-b 0` / `-f 80.0 -b 100` を実行し、
  **`IOHIDManager`経由でのHIDレポート送信が実機で成功**（青色LEDの明るさ変化・消灯、
  FM選局コマンドの送信をコマンドラインから実施）
- `xcodebuild -project radioORCA.xcodeproj -scheme radioORCA build` が成功、
  生成された `radioORCA.app` の起動・終了も確認
- 開発ビルドはアドホック署名（`Sign to Run Locally`）のため
  「Disabling hardened runtime with ad-hoc codesigning」の注記が出る。
  Developer ID署名＋Hardened Runtime＋notarizeはPhase 6で対応

これにより **M1（SwiftでLED点灯・選局がCLIから実機動作）を達成**。

### 2026-08-16：LED点灯が視認できない問題の切り分け（解決）

ユーザーによる目視確認で「消灯は見えるが、点灯（明るさ変化）が確認できない」
という報告があり、ハードウェア故障の懸念が挙がった。切り分けのため
`radiosh-cli` に診断用の `-w <秒>` オプション（HID接続を閉じずに指定秒数
待機してから終了）を追加し、`radiosh-cli -b 127 -w 8` を実行したところ、
**8秒間はっきり点灯し続け、プロセス終了後も消灯しない**ことを実機で確認した。

**原因**：それまでのCLI実行は「接続→レポート送信→即プロセス終了
（`HIDController.deinit`で`IOHIDManagerClose`）」を毎回繰り返しており、
点灯コマンドの効果がごく短時間しか目視できていなかった（一瞬の変化として
しか見えなかった）。ハードウェア側は正常で、**一度送信したLED状態は
ホスト接続の有無に関わらず保持される**ことも合わせて判明した
（`hardware-protocol.md` に追記予定）。

これにより点灯・消灯コマンドの実装が完全に正しいことを実機で再確認できた。
`-w`オプションは診断用として`radiosh-cli`に残してある。

### 2026-08-16：Phase 2 実装・実機動作確認

`RadioSharkKit`にオーディオ関連コア（`RingBuffer`/`TimeshiftBuffer`/
`TimeshiftPlaybackController`/`AudioDeviceMatch`/`RecordingSession`/
`AudioEngineController`）を実装し、手動確認用CLI `radioaudio-cli` を追加。
純粋ロジック部分は`swift test`でユニットテスト（19件追加、既存6件と合わせて
計25件全通過）。以下を実機で確認した。

1. **1回目の実装（単一`AVAudioEngine`でinputNode/outputNodeを直結する案）は
   実機で起動失敗**：`kAudioUnitErr_FormatNotSupported`
   （"IsFormatSampleRateAndChannelCountValid(outputHWFormat)"）。
   `system_profiler SPAudioDataType`で確認したところ、radioSHARK 2は
   **Output Channelsを持たない入力専用オーディオデバイス**だった。macOSの
   `AVAudioEngine`は`inputNode`/`outputNode`が同一のHAL I/Oユニットを
   共有するため、`inputNode`をradioSHARKに向けると`outputNode`側も
   出力チャンネル0のradioSHARKに巻き込まれてしまうことが原因（詳細は
   `hardware-protocol.md` §8に追記済み）。
2. **設計を「キャプチャ専用エンジン（radioSHARK）＋再生専用エンジン
   （既定の出力デバイス）を分離し、キャプチャしたバッファを
   `AVAudioPlayerNode`で転送する」構成に修正**（`AudioEngineController`）。
   修正後、実機で`radioaudio-cli -m 3`によるライブモニタリングを試行。
   → **チューニング前だったため無音**（想定通り。ラジオのRFフロントエンドが
   何も受信していない状態）。
3. `radiosh-cli -a 810 -b 100` でAM 810kHzにチューニングした状態で
   `radioaudio-cli -m 5` を再実行したところ、**Macのスピーカーから実際に
   音声（ノイズ/放送音）が聞こえることをユーザーが確認**。ライブ再生の
   実装が正しく機能していることを実機で確認できた。
4. `radioaudio-cli -r 5 -s TEST` で5秒間録音し、`~/Music/radioORCA/`配下に
   生成された`.m4a`を`afinfo`で検証。**2ch/48kHz/AAC、estimated
   duration 5.0秒**のファイルが正しく生成されることを確認（検証後、
   テストファイルは削除済み）。
5. `xcodebuild -project radioORCA.xcodeproj -scheme radioORCA build` も
   成功（`NSMicrophoneUsageDescription`は`project.yml`に既に用意済みだった）。

**未検証（Phase 3待ち）**：タイムシフト（Rewind/Fast Forward/Skip/Live復帰）
の`AVAudioPlayerNode`スニペット再生は、操作用UIがまだ無いため実機での
聴感確認ができていない。状態機械（`TimeshiftPlaybackController`）自体は
純粋ロジックとしてユニットテスト済み。

これにより **M2のコア部分（ライブ再生・録音）を実機で達成**。

### 2026-08-16：バンドルID・Team ID・配布経路の会社情報反映

当初`com.bitzgroup`で仮設定していたバンドルIDを、実際の配布主体である
`jp.co.bitz`（自社ドメイン）に変更（`project.yml`の`bundleIdPrefix`と
`PRODUCT_BUNDLE_IDENTIFIER`）。あわせて`DEVELOPMENT_TEAM`に自社のApple
Developer Team ID（`XKY95WKF3J`）を設定（参考：社内の別リポジトリ
`bitzcojp/backgammon`の`project.yml`と同じTeam ID）。Team IDはコード署名済み
バイナリ自体から読み取れる非機密情報のため、publicリポジトリへの記載は
問題ないと判断した。`xcodegen generate`で再生成し、`xcodebuild`でビルド
成功を確認済み。
