# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクトの現状

このリポジトリは現時点で**ドキュメントのみ**（ソースコードやXcode/SwiftPM
プロジェクトはまだ存在しない）。目的は、最新macOSで動作しなくなった
Griffin Technology製の生産終了デスクトップアプリ「radioSHARK 2」を、
OSSとしてゼロから再実装すること。ビルド・lint・テストの対象は今のところ何もない。

Swiftプロジェクトを作成した段階（`docs/implementation-plan.md` のPhase 0参照）で、
実際のビルド/テスト/lintコマンド（アプリターゲットは `xcodebuild`、
`RadioSharkKit` パッケージは `swift test` を想定）をこのファイルに追記すること。
その環境ができる前にコマンドを推測で書かないこと。

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
  `RadioSharkKit`（デバイス検出・HID制御・周波数エンコード・オーディオエンジン）を想定。
  プロトコル層を独立してユニットテストできるようにするため。テストは
  Swift Testingを第一候補とする。
- アプリ名は **radioORCA**。「radioSHARK」はGriffinの商標のため、
  本プロジェクトでは対応ハードウェア名としての説明的言及にとどめる。

## このリポジトリ特有の作法

- ドキュメントは日本語で記述する（主担当者の作業言語のため）。今後追加する
  ドキュメントもこれに合わせること。
- `docs/hardware-protocol.md` §9に挙げた参照実装（`rslight.c`、`radiosh.c` 等）の
  コードをそのまま複製しないこと。引き継いでよいのは文書化されたバイト単位の
  プロトコル仕様のみ。Griffin純正アプリのUIグラフィック・アイコン意匠・
  マニュアル本文も複製しないこと。
