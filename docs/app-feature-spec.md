# radioSHARK 2.0（Griffin純正アプリ）機能仕様

Griffin Technology 公式マニュアル「radio Shark 2.0 reference manual」
（`https://www.gladbird.com/pdf/userGuides/radioSharkManual.pdf`）を基に、
再実装すべき機能を項目化したもの。本プロジェクトのUIおよび挙動の
リファレンス仕様として使う。

## 0. 著作権・商標に関する注意

本書はマニュアルに記載された**機能・操作仕様（アイデア／事実）**を
インターオペラビリティ（相互運用性）確保の目的で抽出した要件リストであり、
Griffin純正アプリの**実装や表現そのもの**を複製する意図はない。実装にあたり
以下を厳守する。

- **著作権**：マニュアルの文章・図版・アイコンのグラフィック意匠、
  アプリのビジュアルデザイン（配色・レイアウトの具体的な表現、
  スクリーンショット中のグラフィック等）は複製・トレースしない。
  UIは本書の機能一覧を満たす**独自デザイン**で実装する
  （配色・アイコン・文言はオリジナルに起こす）。
- **商標**：「radioSHARK」「Griffin」およびそのロゴはGriffin Technology /
  Griffin Innovation の商標。本プロジェクトの成果物（アプリ名・アイコン・
  README等）では自社製品であるかのような誤認を避けるため、
  既存プロトタイプ名 **「radioORCA」** など独自ブランドを正式なアプリ名に用い、
  「radioSHARK」は「対応ハードウェア名」としての説明的言及（nominative use）
  に限定する。GitHubリポジトリ名も `bitzgroup/radioSHARK` から
  `bitzgroup/radioORCA` に改名済み（2026-08-16）。
- **マニュアル本文の引用**：本書中の表・箇条書きは要約・言い換えであり、
  原文の逐語転載は避けている。詳細確認が必要な場合は原本PDFを直接参照する。

## 1. メインウィンドウ

### 1.1 チューニングコントロール
- **Tune Up / Tune Down**：Preferencesの刻み幅に従って周波数を増減。
  押しっぱなしで連続変化。ショートカット：↑ / ↓
- **Favorites**：現在の局を説明つきでお気に入り登録。長押し/Ctrl+クリック/
  右クリックでお気に入りメニューを表示、すばやく切替可能。
- **AM/FM切替**
- **Tuning Slider**：周波数を直接ドラッグで選局
- **直接入力**：ウィンドウがアクティブな状態で数字＋Returnキーを押すと
  直接その周波数にチューニング（例：`104.5` + Return）。Escapeでキャンセル。
- **スクロールホイール**：チューニングに使用可能
- **Tabキー**：上にシーク、Shift+Tabで下にシーク

### 1.2 再生コントロール
- **Volume Slider**：⌘+ / ⌘− でも増減。Shift+スクロールホイールでも可
- **Mute**：スピーカーアイコンの波紋表示でミュート状態を示す
- **Record**：新規録音を開始。名前と保存先を聞かれる。録音中はボタンが赤点灯。
  ⌘+S
- **Skip Back / Skip Ahead**：タイムシフト再生位置を固定時間 or
  先頭/末尾までジャンプ（時間はPreferencesで設定）。Home / End
- **Rewind / Fast Forward**：押すたびに速度が上がる可変速。⌘中は色が青に変化。
  ← / →
- **Play/Pause**：再生中は緑色に変化。録音は一時停止されない
  （タイムシフトのポーズのみ）。Space
- **Live**：いつでもライブ音声に復帰。L

### 1.3 ステータス表示
- **Status Icon**：局の種別アイコン。Ctrl+クリックでアイコン選択。
  URLが設定されていればクリックでブラウザを開く
- **Spectrum/Frequency 切替表示**：スペクトラム表示 or 大きな周波数表示
- **Playback Indicator**：`LIVE` 表示、または録音のタイムコード表示。
  クリック/ドラッグで再生位置移動
- **Schedule ボタン**：スケジュールウィンドウを開く
- **EQ ボタン**：イコライザーウィンドウを開く
- **Station Description**：局名 or 再生中トラックのタイトル表示。⌘+I で編集
- **Fin（USB接続インジケーター）**：
  - グレー：未接続
  - 青：接続中
  - 赤：接続中＋録音中
  - USBアイコン点滅：デバイス未検出

## 2. 局情報（Station Info）— ⌘+I
| フィールド | 内容 |
|---|---|
| Favorite | お気に入り登録チェック |
| Description | 局名 |
| URL | 局のWebサイト |
| Phone | 電話番号 |
| Genre | ジャンル（プルダウン） |
| Icon | アイコン選択 |
| Preset Key | お気に入りのみ ⌘+1〜9 に割当可（9個まで） |

## 3. スケジュール録音（Schedule ウィンドウ）

### 3.1 Scheduledタブ
- 一覧列：Title / Date / Time / Length / Station / Repeat / End
- **New Event**：現在時刻+10分後の仮イベントを追加、各項目をダブルクリックで編集
- **Station選択**：お気に入りからのポップアップ、または直接入力（デフォルトは
  現在チューニング中の局）
- **Repeat**：Never / Daily / Weekly / Monthly / Yearly / Custom
  - Custom例：平日のみ、週末のみ、「毎月第2月曜」、「4年ごと11月第1火曜」等、
    曜日・週番号・月指定の組み合わせが可能
  - 終了条件：Count（回数指定）または On Date（日付指定）
- **フィルタ**：「before」「after」の日付でイベント表示範囲を絞り込み

### 3.2 Recordedタブ
- 一覧列：Title / Date / Time / Length / Station
- 録音済みアイテムのダブルクリックで再生、Deleteキーで削除
- ステータスアイコン：録音済み／録音中／再生中／録音中データを再生中

## 4. 環境設定（Preferences）

### 4.1 Record & Playback
- Bookmarkable（AACのみ、iPod/iTunesとの再生位置同期）
- Recording format（AAC等）/ Recording quality（ビットレート）
- Skip Left/Right の挙動：先頭/末尾へ or 指定秒数
- Recording folder location（デフォルト `~/Music/radioSHARK/`）
- Timeshift：Enable + Buffer length（分）。**循環バッファ**方式
  （バッファ長を超えると先頭から上書き）
- iTunes連携：録音をiTunesの指定プレイリストに自動追加
  （→現代的には Music.app への追加、または廃止して
  Finder/ライブラリ管理のみにするかは要検討）

### 4.2 Tuning
- FM Tuning range：Standard / Japanese
- Tune which FM frequencies：Odd / Even / All
- AM tuning increment：9kHz / 10kHz

### 4.3 Appearance
- radioSHARK light：On / Off / Pulse（※v2でPulse対応かは要検証、
  `hardware-protocol.md` §10参照）
- Display Color：アプリUIのアクセントカラー

### 4.4 Updates
- 起動時のアップデート確認チェックボックス
  （→本プロジェクトではGitHub Releases APIでのバージョンチェックに置換）

## 5. イコライザー
- 10バンド（32/64/125/250/500/1k/2k/4k/8k/16k Hz）、±12dB
- プリセット：Bass Booster / Bass Reducer / Classical / Hip-Hop / Jazz / Flat /
  Pop / R&B / Rock / Small Speakers / Spoken Word / Treble Booster /
  Treble Reducer / Vocal Booster
- Make Preset（ユーザー定義保存）/ Edit List
- → `AVAudioUnitEQ` で10バンドパラメトリックEQとして実装可能

## 6. ファイル管理
- 録音ファイルは `~/Music/radioSHARK/` に保存
- iTunes連携時はiTunesライブラリにもコピーされ二重管理になる
  （本プロジェクトでは二重コピーは避け、単一ソース管理を検討）

## 7. ショートカットキー一覧（P.23）

| 操作 | キー |
|---|---|
| Tune up | ↑ |
| Tune down | ↓ |
| Seek up | Tab |
| Seek down | Shift+Tab |
| Volume up | ⌘+= |
| Volume down | ⌘+− |
| Skip Back | Home |
| Skip Ahead | End |
| Rewind | ← |
| Fast Forward | → |
| Live Radio | L |
| Pause Playback | Space |
| Station Info | ⌘+I |
| Set Favorite | ⌘+D |
| Minimize Window | ⌘+M |
| Open Presets | ⌘+, |
| Start Recording | ⌘+S |
| radioSHARK Help | ⌘+H |

## 8. その他（Last-Minute Notes）
- **Dashboard Widget**（Tiger時代のDashboard機能。現代のmacOSには存在しない
  ため対象外。代替として **メニューバーアプリ / ウィジェット（WidgetKit）**
  を検討する価値あり）
- **AppleScript対応**（辞書経由でコマンド実行可能だった。
  現代的には `App Intents` / Shortcuts.app 対応が相当する）

## 9. 本プロジェクトでのスコープ判断（初期リリース向け）

MVP（最小限のリリース）では以下を優先し、それ以外はPhase分けして後回しにする
（詳細は `implementation-plan.md` 参照）。

- **必須**：selo（AM/FM選局）、LED状態連動、ライブ再生、録音、
  お気に入り、基本ショートカット
- **次点**：タイムシフト再生、スケジュール録音、EQ
- **見送り候補**：Dashboardウィジェット、AppleScript、iTunes自動連携
  （Music.appへの手動ドラッグ運用や"Finderで開く"で代替）
