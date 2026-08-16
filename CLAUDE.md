# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクトの現状

最新macOSで動作しなくなったGriffin Technology製の生産終了デスクトップアプリ
「radioSHARK 2」を、OSSとしてゼロから再実装するプロジェクト。Phase 0-1
（`docs/implementation-plan.md`参照）まで完了しており、`RadioSharkKit`
パッケージによるHID制御（LED・チューニング）は実機で動作確認済み。

### ビルド・テスト

```sh
# RadioSharkKit（コアロジック）のビルド・テスト
cd RadioSharkKit
swift build
swift test                       # Swift Testingで実行

# 実機に対する手動動作確認（radioSHARK 2が接続されている前提）
swift run radioorca-cli -b 40      # 青色LED輝度40
swift run radioorca-cli -f 80.0    # FM 80.0MHzにチューニング
swift run radioorca-cli -h         # 使い方

# アプリ本体（radioORCA.xcodeproj）
# project.ymlを編集したら再生成すること
xcodegen generate
xcodebuild -project radioORCA.xcodeproj -scheme radioORCA build
```

単体テストを1件だけ実行する場合は `swift test --filter <TestName>` を使う
（例: `swift test --filter FrequencyCodecTests`）。

`radioORCA.xcodeproj` は `project.yml`（xcodegen）から生成される派生物。
プロジェクト構成を変えるときは **`project.yml` を編集してから
`xcodegen generate` で再生成**すること。`.xcodeproj` を直接手編集しない。

## 一次情報は docs/ にある

技術的な決定事項はすべて `docs/` 配下にある。アーキテクチャや実装方針を
提案する前に必ず参照すること。

- `docs/hardware-protocol.md` — radioSHARK 2のUSB HIDプロトコルの実機解析結果
  （Vendor/Product ID、LED・チューニングのHIDレポートバイト列、周波数エンコード式、
  実機検証ログ、実機で未確認の項目）。
- `docs/app-feature-spec.md` — Griffin純正アプリの機能仕様（UI/挙動のリファレンス。
  UIデザインに手を付ける前に必ず§0の著作権・商標に関する注意を読むこと）。
- `docs/implementation-plan.md` — フェーズ分けした実装計画、アーキテクチャの決定事項、
  実機検証ログ。**スコープに関する決定はここが正**（例：v2専用、非サンドボックス／無料、
  配布経路など）。「まだ決まっていないはず」と思う前にまずここを確認する。

## 既に確定している主な決定事項（詳細は implementation-plan.md の表を参照）

- **radioSHARK 2（v2）専用**。v1（初代RadioSHARK）は明確にスコープ外
  （HIDレポート長が6バイトvs7バイトで異なる。v1の情報は背景資料としてのみ記載）。
- **App Sandboxは使わない**。Developer ID署名＋公証（notarize）を行い、
  このパブリックリポジトリのGitHub Releasesからdmgを直接配布する。
  Mac App Storeには出さない。
- **無料**。寄付・課金の仕組みは設けない。
- デバイス制御は現行の高レベルAPIである **`IOHIDManager`** を使う。
  この仕様の出典であるrslight/radiosh等の歴史的CLIツールが使っている
  古い `IOCFPlugIn`/`IOHIDDeviceInterface**` 方式は参照しない。
  それらのツールから引き継ぐのは**バイトレイアウト・周波数計算式という
  プロトコルの事実のみ**で、コードは一切流用しない
  （`docs/hardware-protocol.md` §9のライセンス注意を参照）。
- 音声の録音・再生に独自プロトコルは不要。radioSHARKは標準のUSB Audio Class
  デバイスとして認識される（実機検証済み：追加ドライバなしで
  `AVAudioEngine`/CoreAudioから通常のUSB入力として扱える）。
- モジュール構成はアプリターゲット＋ローカルSwiftPMパッケージ
  `RadioSharkKit`（デバイス検出・HID制御・周波数エンコード。オーディオエンジンは
  Phase 2で追加予定）。プロトコル層を独立してユニットテストできるようにするため。
  テストはSwift Testingを使う（実装済み）。
- アプリ名は **radioORCA**。「radioSHARK」はGriffinの商標のため、
  本プロジェクトでは対応ハードウェア名としての説明的言及にとどめる。
- **コード内のユーザー向け文字列（UIテキスト、CLI出力、エラーメッセージ）は
  英語をベース言語とする**。日本語はXcodeの String Catalog
  （`App/radioORCA/Localizable.xcstrings`）や `ja.lproj/InfoPlist.strings`
  でローカライズとして提供する。`docs/`配下のドキュメント（日本語）とは
  別の話なので混同しないこと。新しいUI文字列を追加したら、対応する
  日本語訳を必ずString Catalogに追加する。

## ディレクトリ構成

- `RadioSharkKit/` — ローカルSwiftPMパッケージ（`Package.swift`）。
  - `Sources/RadioSharkKit/` — `DeviceIdentity`（Vendor/Product ID）、
    `FrequencyCodec`（周波数⇔バイト列変換）、`HIDReports`（レポート生成、
    純粋関数でテストしやすい）、`HIDController`（`IOHIDManager`ラッパー、
    実際にopen/setReportする）、`DeviceDiscovery`（接続/切断監視、まだ
    アプリ本体には未接続）。
  - `Sources/radioorca-cli/` — 実機での手動確認用CLI実行ファイル。
  - `Tests/RadioSharkKitTests/` — Swift Testingによるユニットテスト
    （`FrequencyCodec`/`HIDReports`の純粋関数のみを対象。実機は不要）。
- `App/radioORCA/` — SwiftUIアプリのソース（`radioORCAApp.swift`,
  `ContentView.swift`）。現状はPhase 0/1の配線確認用の最小プレースホルダーで、
  本格的なUIはPhase 3（`docs/app-feature-spec.md`が仕様）。
- `project.yml` — `radioORCA.xcodeproj` の生成元（xcodegen）。

## このリポジトリ特有の作法

- ドキュメントは日本語で記述する（主担当者の作業言語のため）。今後追加する
  ドキュメントもこれに合わせること。
- `docs/hardware-protocol.md` §9に挙げた参照実装（`rslight.c`、`radiosh.c` 等）の
  コードをそのまま複製しないこと。引き継いでよいのは文書化されたバイト単位の
  プロトコル仕様のみ。Griffin純正アプリのUIグラフィック・アイコン意匠・
  マニュアル本文も複製しないこと。
