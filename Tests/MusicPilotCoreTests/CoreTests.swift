import XCTest
import AVFoundation
@testable import MusicPilotCore

final class CoreTests: XCTestCase {
    private func fixture() throws -> (URL, AudioMetadata) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("テスト,\"音源\".wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96_000)!
        buffer.frameLength = 96_000
        for channel in 0..<2 {
            for i in 0..<96_000 { buffer.floatChannelData![channel][i] = Float(sin(Double(i) * 2 * .pi * 440 / 48_000)) * 0.1 }
        }
        do { let file = try AVAudioFile(forWriting: url, settings: format.settings); try file.write(from: buffer) }
        return (url, try AVAudioMetadataReader().load(url: url))
    }
    func testPCMMetadata() throws {
        let (url, metadata) = try fixture(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertEqual(metadata.duration, 2, accuracy: 0.00001)
        XCTAssertEqual(metadata.sampleRate, 48_000)
        XCTAssertEqual(metadata.channelCount, 2)
        XCTAssertEqual(metadata.frameCount, 96_000)
        XCTAssertEqual(metadata.codec, "PCM")
        XCTAssertEqual(metadata.sourceBitDepth, 32)
        XCTAssertGreaterThan(metadata.fileSize, 0)
    }
    func testRejectsInvalidMissingDirectoryAndRemote() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try Data("not audio".utf8).write(to: url); defer { try? FileManager.default.removeItem(at: url) }
        let reader = AVAudioMetadataReader()
        XCTAssertThrowsError(try reader.load(url: url))
        XCTAssertThrowsError(try reader.load(url: url.appendingPathExtension("missing")))
        XCTAssertThrowsError(try reader.load(url: FileManager.default.temporaryDirectory))
        XCTAssertThrowsError(try reader.load(url: URL(string: "https://example.com/audio.wav")!))
    }
    func testNoInventedAnalysisAndJSONRoundTrip() async throws {
        let (url, metadata) = try fixture(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = try await UnavailableAnalysisService().analyze(url: url, metadata: metadata)
        XCTAssertNil(result.bpm); XCTAssertNil(result.key); XCTAssertNil(result.chords)
        XCTAssertNil(result.sections); XCTAssertNil(result.tempoMap); XCTAssertNil(result.beats)
        XCTAssertEqual(result.statuses.count, Feature.allCases.count)
        XCTAssertTrue(result.statuses.allSatisfy { $0.availability == .notImplemented })
        let doc = AnalysisDocument(audio: metadata, analysis: result, referenceTempo: 97.5)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AnalysisDocument.self, from: ExportService.json(doc))
        XCTAssertEqual(decoded.audio, metadata)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.referenceTempo, 97.5)
        XCTAssertTrue(decoded.referenceTempoSource.contains("not detected"))
    }
    func testCSVEscaping() async throws {
        let (url, metadata) = try fixture(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = try await UnavailableAnalysisService().analyze(url: url, metadata: metadata)
        let text = String(decoding: ExportService.csv(AnalysisDocument(audio: metadata, analysis: result, referenceTempo: 120)), as: UTF8.self)
        XCTAssertTrue(text.contains("\"テスト,\"\"音源\"\".wav\""))
        XCTAssertTrue(text.contains("notImplemented"))
        XCTAssertTrue(text.contains("user-entered; not detected from audio"))
    }
    func testTempoMIDIWithIndependentSystemParser() throws {
        for bpm in [20.0, 97.5, 120, 300] {
            let data = try ExportService.referenceTempoMIDI(bpm: bpm)
            var sequence: MusicSequence?
            XCTAssertEqual(NewMusicSequence(&sequence), noErr)
            guard let sequence else { return XCTFail("No sequence") }
            defer { DisposeMusicSequence(sequence) }
            XCTAssertEqual(MusicSequenceFileLoadData(sequence, data as CFData, .midiType, []), noErr)
            var track: MusicTrack?
            XCTAssertEqual(MusicSequenceGetTempoTrack(sequence, &track), noErr)
            var iterator: MusicEventIterator?
            XCTAssertEqual(NewMusicEventIterator(track!, &iterator), noErr)
            defer { DisposeMusicEventIterator(iterator!) }
            var foundTempo = false; var hasEvent = DarwinBoolean(false)
            MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
            while hasEvent.boolValue {
                var time: MusicTimeStamp = 0; var type: MusicEventType = 0
                var pointer: UnsafeRawPointer?; var size: UInt32 = 0
                MusicEventIteratorGetEventInfo(iterator!, &time, &type, &pointer, &size)
                if type == kMusicEventType_ExtendedTempo {
                    let event = pointer!.load(as: ExtendedTempoEvent.self)
                    XCTAssertEqual(event.bpm, bpm, accuracy: 0.001); foundTempo = true
                }
                XCTAssertNotEqual(type, kMusicEventType_MIDINoteMessage)
                MusicEventIteratorNextEvent(iterator!); MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
            }
            XCTAssertTrue(foundTempo)
        }
    }
    func testInvalidTempoRejected() {
        for bpm in [0.0, -1, 19.99, 300.1, .nan, .infinity] { XCTAssertThrowsError(try ExportService.referenceTempoMIDI(bpm: bpm)) }
    }
    func testExternalAudioFormats() throws {
        guard let path = ProcessInfo.processInfo.environment["MUSICPILOT_TEST_AUDIO"] else {
            throw XCTSkip("Set MUSICPILOT_TEST_AUDIO to the generated format-fixture directory")
        }
        for ext in ["wav", "mp3", "m4a", "aiff"] {
            let metadata = try AVAudioMetadataReader().load(url: URL(fileURLWithPath: path).appendingPathComponent("fixture." + ext))
            XCTAssertEqual(metadata.duration, 3, accuracy: 0.08, ext)
            XCTAssertEqual(metadata.sampleRate, 44_100, ext)
            XCTAssertEqual(metadata.channelCount, 1, ext)
        }
    }
}
