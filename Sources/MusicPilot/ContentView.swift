import SwiftUI
import UniformTypeIdentifiers
import MusicPilotCore

enum Page: String, CaseIterable, Identifiable {
    case analyze = "Analyze", stems = "Stems", groove = "Groove", midi = "MIDI", export = "Export"
    var id: String { rawValue }
    var icon: String {
        switch self { case .analyze: return "waveform.path"; case .stems: return "square.stack.3d.up"; case .groove: return "metronome"; case .midi: return "pianokeys"; case .export: return "square.and.arrow.up" }
    }
    var subtitle: String {
        switch self { case .analyze: return "音源を知る"; case .stems: return "パートに分ける"; case .groove: return "タイミングを探る"; case .midi: return "演奏を取り出す"; case .export: return "制作へつなぐ" }
    }
}
private let accent = Color(red: 0.38, green: 0.85, blue: 0.77)
private let surface = Color(red: 0.105, green: 0.125, blue: 0.16)

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var page: Page = .analyze
    @State private var targeted = false
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    dropZone
                    if model.isLoading {
                        HStack(spacing: 12) { ProgressView().controlSize(.small); Text("音声情報を読み込んでいます…") }.padding()
                    }
                    if let metadata = model.metadata { audioSummary(metadata) }
                    switch page {
                    case .analyze: analyzeView
                    case .stems: plannedView(icon: "square.stack.3d.up", title: "パート別の音源を、ひとつの場所に。", text: "Vocal / Drums / Bass / Guitar / Otherへの分離を予定しています。現在は分離エンジン未接続のため、ステムは生成できません。", chips: ["Vocal", "Drums", "Bass", "Guitar", "Other"])
                    case .groove: plannedView(icon: "metronome", title: "揺れを残して、ノリを見つける。", text: "将来、基準拍と各楽器の発音時刻を比較し、前後の偏差をmsで表示します。拍・発音検出エンジンは未接続です。現在、タイミングの数値や良否判定は表示しません。", chips: ["基準拍", "発音時刻", "偏差 ±ms"])
                    case .midi: plannedView(icon: "pianokeys", title: "音声から、編集できる演奏へ。", text: "Bass / Drums / MelodyのAudio → MIDI変換を予定しています。採譜エンジンは未接続です。Exportでは、手入力のテンポだけを含む参照用MIDIを書き出せます。", chips: ["Bass", "Drums", "Melody"])
                    case .export: exportView
                    }
                    if let notice = model.notice { Label(notice, systemImage: "checkmark.circle.fill").foregroundStyle(accent).textSelection(.enabled) }
                    Text("LOCAL FIRST  •  音声はこのMac上で読み込みます。外部送信はありません。")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }.padding(30).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Color(red: 0.065, green: 0.078, blue: 0.105))
        }
        .tint(accent)
        .alert("MusicPilot", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill").font(.system(size: 36)).foregroundStyle(accent)
                Text("MusicPilot").font(.system(size: 23, weight: .bold))
            }.padding(.bottom, 32).padding(.top, 18)
            Text("WORKSPACE").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 12)
            ForEach(Page.allCases) { item in
                Button { page = item } label: {
                    HStack(spacing: 13) {
                        Image(systemName: item.icon).font(.system(size: 23)).frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.rawValue).font(.system(size: 18, weight: .semibold))
                            Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(14).foregroundStyle(page == item ? accent : .white.opacity(0.8))
                        .background(page == item ? accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityLabel(item.rawValue)
            }
            Spacer()
            Text("VERSION 1.0 · MVP").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text("解析エンジンは今後追加予定").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 220).background(Color(red: 0.085, green: 0.1, blue: 0.13))
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(page.rawValue).font(.system(size: 34, weight: .bold))
            Text(page == .analyze ? "音源を読み込み、制作の出発点を整える。" : page.subtitle).font(.system(size: 16)).foregroundStyle(.secondary)
        }
    }
    private var dropZone: some View {
        HStack(spacing: 22) {
            Image(systemName: "waveform.badge.plus").font(.system(size: 42)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 8) {
                Text("音声ファイルをドロップ").font(.system(size: 21, weight: .semibold))
                Text("WAV / MP3 / AIFF / M4A / CAF など · 1ファイルずつ")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(action: model.chooseFile) { Label("ファイルを選ぶ", systemImage: "folder").font(.system(size: 15, weight: .semibold)).padding(.vertical, 8) }
                .buttonStyle(.borderedProminent).controlSize(.large).foregroundStyle(.black)
        }.padding(24).frame(maxWidth: .infinity, minHeight: 116)
            .background(targeted ? accent.opacity(0.13) : surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(accent.opacity(targeted ? 1 : 0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7,5])))
            .onDrop(of: [UTType.fileURL], isTargeted: $targeted, perform: model.acceptDrop)
    }
    private func audioSummary(_ m: AudioMetadata) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text(m.filename).font(.system(size: 19, weight: .semibold)).lineLimit(2).textSelection(.enabled)
                    Label("読み込み済み", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(accent)
                }
                Spacer()
                Button(action: model.togglePlayback) { Label(model.isPlaying ? "一時停止" : "再生", systemImage: model.isPlaying ? "pause.fill" : "play.fill").padding(7) }.controlSize(.large)
                Button(action: model.stopPlayback) { Image(systemName: "stop.fill").padding(7) }.controlSize(.large).accessibilityLabel("停止")
            }
            HStack(alignment: .top, spacing: 24) {
                metric("長さ", String(format: "%d:%06.3f", Int(m.duration) / 60, m.duration.truncatingRemainder(dividingBy: 60)))
                metric("サンプルレート", String(format: "%.1f kHz", m.sampleRate / 1000))
                metric("チャンネル", "\(m.channelCount) ch")
                metric("形式", "\(m.container) · \(m.codec)")
            }
            Text("\(ByteCountFormatter.string(fromByteCount: m.fileSize, countStyle: .file))  ·  \(m.sourceBitDepth.map { "\($0) bit" } ?? "ビット深度：未取得／非適用")  ·  \(m.frameCount.formatted()) frames")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).background(surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .medium, design: .rounded)).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var analyzeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("音楽解析").font(.title2.weight(.semibold)); Spacer(); Text("エンジン未接続").font(.caption).foregroundStyle(.orange) }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                analysisCard("BPM", "テンポ検出", "speedometer")
                analysisCard("Key", "調性の推定", "key")
                analysisCard("Chords", "コード進行", "pianokeys")
                analysisCard("Structure", "曲構成", "rectangle.split.3x1")
                analysisCard("Tempo Map", "可変テンポ", "point.topleft.down.curvedto.point.bottomright.up")
                analysisCard("Groove", "拍に対する偏差", "metronome")
            }
            Text("現在は基本メタデータを取得できます。BPM・Key・コード・構成・可変テンポは未実装です。推定値や仮の解析結果は表示しません。")
                .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func analysisCard(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: icon).foregroundStyle(accent.opacity(0.7)); Text(title).fontWeight(.semibold) }
            Text("未実装").font(.system(size: 24, weight: .medium)).foregroundStyle(.secondary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func plannedView(icon: String, title: String, text: String, chips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("未実装 · エンジン未接続", systemImage: "info.circle").font(.callout).foregroundStyle(.orange)
            Image(systemName: icon).font(.system(size: 46)).foregroundStyle(accent).padding(.top, 8)
            Text(title).font(.system(size: 25, weight: .semibold))
            Text(text).font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
            HStack { ForEach(chips, id: \.self) { Text($0).font(.callout).padding(.horizontal, 14).padding(.vertical, 9).background(.white.opacity(0.06), in: Capsule()) } }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(28).background(surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private var exportView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Logic Proへ、必要なデータを。").font(.title2.weight(.semibold))
            Text("JSON / CSVには取得した情報と未実装の状態を記録します。元の音声は変更しません。")
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Text("参照テンポ（手入力）").font(.headline)
                TextField("BPM", value: $model.manualBPM, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).frame(width: 100).font(.title3)
                Text("BPM · 20〜300").foregroundStyle(.secondary)
            }.padding(18).background(surface, in: RoundedRectangle(cornerRadius: 12))
            ForEach(ExportKind.allCases, id: \.rawValue) { kind in
                Button { model.export(kind) } label: {
                    HStack {
                        Image(systemName: kind == .midi ? "pianokeys" : "doc.text").font(.title2).frame(width: 34)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(kind.title).font(.system(size: 18, weight: .semibold))
                            Text(kind == .midi ? "固定テンポ + 4/4拍子のみ。音符・自動採譜・可変テンポは含みません。" : "ファイル情報と解析の実装状態を保存")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "arrow.down.to.line")
                    }.padding(18).background(surface, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(model.metadata == nil || model.isLoading)
            }
            if model.metadata == nil { Text("音声ファイルを読み込むと書き出せます。").foregroundStyle(.orange) }
            Text("MIDIは参照用のテンポイベントのみです。Logic Proでの読み込み結果は未検証です。JSON / CSVは確認・他ツール連携用で、Logic専用プロジェクトではありません。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
