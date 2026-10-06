import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MusicPilotCore

@MainActor final class AppModel: ObservableObject {
    @Published var metadata: AudioMetadata?
    @Published var analysis: AnalysisResult?
    @Published var isLoading = false
    @Published var isPlaying = false
    @Published var error: String?
    @Published var notice: String?
    @Published var manualBPM = 120.0
    private var activeURL: URL?
    private var securityScoped = false
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private let reader: any AudioMetadataLoading
    private let analyzer: any MusicAnalysisService
    private var timer: Timer?

    init(reader: any AudioMetadataLoading = AVAudioMetadataReader(), analyzer: any MusicAnalysisService = UnavailableAnalysisService()) {
        self.reader = reader; self.analyzer = analyzer
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let playing = self.player?.isPlaying ?? false
                if self.isPlaying != playing { self.isPlaying = playing }
            }
        }
    }
    func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "MusicPilotで音声を開く"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        let window = NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            let url = panel.url
            panel.orderOut(nil)
            Task { @MainActor in
                window?.makeKeyAndOrderFront(nil)
                if response == .OK, let url { self?.load(url) }
            }
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func load(_ url: URL) {
        task?.cancel(); player?.stop(); player = nil; isPlaying = false
        if securityScoped, let activeURL { activeURL.stopAccessingSecurityScopedResource() }
        activeURL = url; securityScoped = url.startAccessingSecurityScopedResource()
        metadata = nil; analysis = nil; notice = nil; error = nil; isLoading = true
        let id = UUID(); requestID = id
        let reader = self.reader; let analyzer = self.analyzer
        task = Task {
            do {
                let info = try await Task.detached(priority: .userInitiated) { try reader.load(url: url) }.value
                try Task.checkCancellation()
                let result = try await analyzer.analyze(url: url, metadata: info)
                try Task.checkCancellation()
                guard id == requestID else { return }
                metadata = info; analysis = result; isLoading = false
            } catch is CancellationError {
                if id == requestID { isLoading = false }
            } catch {
                guard id == requestID else { return }
                self.error = "読み込みに失敗しました。\n\(error.localizedDescription)"
                isLoading = false
                if securityScoped { url.stopAccessingSecurityScopedResource(); securityScoped = false }
                activeURL = nil
            }
        }
    }
    func togglePlayback() {
        guard let url = activeURL, metadata != nil else { return }
        do {
            if player == nil { player = try AVAudioPlayer(contentsOf: url) }
            guard let player else { return }
            if player.isPlaying { player.pause() }
            else { if player.currentTime >= player.duration { player.currentTime = 0 }; guard player.play() else { throw MusicPilotError.invalidAudio } }
            isPlaying = player.isPlaying
        } catch { self.error = "再生できませんでした。\n\(error.localizedDescription)" }
    }
    func stopPlayback() { player?.stop(); player?.currentTime = 0; isPlaying = false }
    func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            Task { @MainActor in
                guard let self else { return }
                if let url { self.load(url) }
                else { self.error = error?.localizedDescription ?? "ファイルを受け取れませんでした。ファイル選択ボタンをお使いください。" }
            }
        }
        return true
    }
    func export(_ kind: ExportKind) {
        guard let metadata, let analysis else { return }
        do {
            guard manualBPM.isFinite, (20...300).contains(manualBPM) else { throw MusicPilotError.invalidTempo }
            let doc = AnalysisDocument(audio: metadata, analysis: analysis, referenceTempo: manualBPM)
            let data: Data
            switch kind {
            case .json: data = try ExportService.json(doc)
            case .csv: data = ExportService.csv(doc)
            case .midi: data = try ExportService.referenceTempoMIDI(bpm: manualBPM)
            }
            let panel = NSSavePanel()
            panel.title = kind.title
            panel.directoryURL = activeURL?.deletingLastPathComponent()
            panel.allowedContentTypes = [kind.contentType]
            let stem = (metadata.filename as NSString).deletingPathExtension
            panel.nameFieldStringValue = stem + (kind == .midi ? "-manual-tempo.mid" : "-analysis." + kind.rawValue)
            let window = NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }
            let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
                let destination = panel.url
                panel.orderOut(nil)
                Task { @MainActor in
                    window?.makeKeyAndOrderFront(nil)
                    guard response == .OK, let destination else { return }
                    do {
                        try data.write(to: destination, options: .atomic)
                        self?.notice = "保存しました：\(destination.lastPathComponent)"
                    } catch { self?.error = "書き出しに失敗しました。\n\(error.localizedDescription)" }
                }
            }
            if let window { panel.beginSheetModal(for: window, completionHandler: completion) }
            else { panel.begin(completionHandler: completion) }
        } catch { self.error = "書き出しに失敗しました。\n\(error.localizedDescription)" }
    }
}

enum ExportKind: String, CaseIterable {
    case json, csv, midi
    var title: String {
        switch self { case .json: return "解析データ JSON"; case .csv: return "メタデータ CSV"; case .midi: return "手入力テンポ MIDI" }
    }
    var contentType: UTType {
        switch self { case .json: return .json; case .csv: return .commaSeparatedText; case .midi: return UTType(filenameExtension: "mid") ?? .data }
    }
}
