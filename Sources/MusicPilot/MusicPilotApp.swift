import SwiftUI
import AppKit

@main struct MusicPilotApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("MusicPilot", id: "main") {
            ContentView().environmentObject(model).preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 700)
                .onOpenURL { url in model.load(url) }
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("音声ファイルを開く…") { model.chooseFile() }.keyboardShortcut("o")
            }
        }
    }
}
