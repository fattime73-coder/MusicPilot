# MusicPilot 1.0 MVP

Apple Silicon / macOS 14以降向けの、Swift・SwiftUI製ローカル音楽制作アシスタントです。
音源を読み込み、基本情報を確認し、他の制作ツールへ渡す土台を実装しています。

## 起動・操作

1. 配布ZIPを展開し、`MusicPilot.app`をダブルクリックしてください。
2. 常用する場合は、**アプリ本体だけ**をApplicationsへ移動できます。ソースコードやPython環境は不要です。
3. Analyze画面の枠に音声ファイルを1つドロップするか、「ファイルを選ぶ」（⌘O）で開きます。
4. ファイル名、長さ、サンプルレート、チャンネル数、形式、取得可能なビット深度、容量を確認できます。
5. 「再生」「一時停止」「停止」でプレビューします。
6. Export画面からJSON・CSV、または手入力の固定テンポMIDIを保存します。

動作検証済みの形式はWAV / MP3 / M4A / AIFFです。CAFなどAVFoundationが扱える形式も対象ですが、コーデックによって読み込めないものがあります。MP3などの長さはデコード用フレーム数から求めるため、エンコーダの余白によって原音より数十ms長く表示される場合があります。

## 実装済み・未実装

| 機能 | 状態 |
| --- | --- |
| Analyze / Stems / Groove / MIDI / Export | 大きなボタンのダークUIで切り替え可能 |
| ファイル選択・Finderからドロップ | 実装済み、1ファイルずつ |
| メタデータ・長さ・プレビュー再生 | 実装済み |
| JSON / CSV出力 | 実装済み。未実装状態と参照テンポの出典も保存 |
| 参照用MIDI | 手入力した固定BPMと4/4拍子のみ。SMF Format 0、480 PPQ |
| BPM / Key / コード / 曲構成 / 可変テンポ | 未実装。解析エンジン未接続 |
| ステム分離 / 音声からMIDI採譜 | 未実装。サービスの契約を定義 |
| Groove Doctor | 基準拍・発音時刻・楽器・信頼度・ms偏差の構造のみ |
| Logic直接制御・.logicx生成 | 対象外 |

未実装機能には値を埋めません。手入力の120 BPMは自動解析結果ではありません。
音声の外部送信・モデルの自動ダウンロード・原音への書き込みは行いません。
再起動時の音源復元やプロジェクト保存はまだありません。

## Logic Proとの受け渡し

JSON / CSVは内容確認や他ツール連携用です。Logicのプロジェクト形式ではありません。
MIDIは固定テンポ・4/4のメタイベントのみで、音符や演奏リージョンを含みません。
Logic側でテンポを採用するかどうかは読み込み方法・プロジェクト設定に依存します。
このMVPではLogic Pro内の取り込み操作は未検証です。必ず新規プロジェクトで確認してください。
原音のWAV等は別途Logicに読み込んでください。

## ビルド

必要なもの: Apple Silicon Mac、macOS 14以降、Swift 6対応のXcodeまたはCommand Line Tools。
外部Swiftパッケージへの依存はありません。Swift 6ツールチェーンのSwift 5言語モードでビルドします。

```sh
cd /path/to/MusicPilot
swift build
swift test
./scripts/build.sh
open dist/MusicPilot.app
```

`build.sh`はarm64 Releaseを生成し、アイコン・Info.plistを含むアプリを組み立て、ローカル用のアドホック署名を付けます。
Developer ID署名・Appleの公証は含みません。別のMacへの一般配布は署名・公証を追加する段階です。
実行時はSwift / Python / FFmpegのインストールは不要です。

```sh
# 圧縮形式も含めてテストする場合のみ、既存のFFmpegを使用
./scripts/test-formats.sh
# アプリ配布用ZIP
ditto -c -k --sequesterRsrc --keepParent dist/MusicPilot.app ../MusicPilot-macOS-arm64.zip
```

## 構成と拡張方法

- `Sources/MusicPilot/` — SwiftUI画面、読み込み状態、エラー、プレビュー、保存ダイアログ。
- `Sources/MusicPilotCore/Models.swift` — エンジン非依存の解析データとサービスprotocol。
- `AudioReader.swift` — AVFoundationによる音声メタデータ取得。デコード処理用のFloat形式と元ファイルのビット深度を区別。
- `Export.swift` — バージョン付きJSON、CSV、参照テンポSMF。
- `Tests/MusicPilotCoreTests/` — 合成音声、エラー、未実装状態、JSON/CSV、OSの独立したMIDIパーサーによる検証。

`AppModel`のコンストラクタに`AudioMetadataLoading`と`MusicAnalysisService`を注入できます。
現在は`UnavailableAnalysisService`がすべての特徴を`notImplemented`として返します。
新しいサービスは`AnalysisResult`にBPM、Key、時刻付きコード・曲構成、テンポ点、拍位置を返します。
未取得の結果はnil、未実装状態は明示的なstatusとして保持します。UIの解析カードはMVPの未実装表示なので、実エンジン接続時に結果・信頼度・失敗状態の表示も追加してください。

`StemSeparationService`、`MIDITranscriptionService`、`GrooveAnalysisService`は将来の接続口です。
Grooveでは正の`offsetMilliseconds`を「基準拍より後」、負を「前」とします。
拍やonsetの検出・対応付け、テンポの揺れと演奏偏差の分離、楽器別統計は未実装です。
将来Python/C++等を接続する場合も、ファイルURL入力→構造化結果出力の境界を維持してください。

新しいファイルを開くと以前の再生を停止し、古い読み込み結果が最新ファイルに混入しないようキャンセルとリクエストIDで防止します。
メタデータ読み込みはバックグラウンドで実行し、画面の再生状態は変化した時だけ更新します。

## Git

このフォルダで独立したローカルGitリポジトリとして管理します。
`.build`、`dist`、一時テストデータは追跡対象外です。公開リポジトリ: [fattime73-coder/MusicPilot](https://github.com/fattime73-coder/MusicPilot)。
検証結果と未検証項目は`VALIDATION.md`を参照してください。
