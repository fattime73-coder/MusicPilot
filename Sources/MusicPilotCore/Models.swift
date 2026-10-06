import Foundation

public struct AudioMetadata: Codable, Sendable, Equatable {
    public let filename: String
    public let container: String
    public let duration: Double
    public let sampleRate: Double
    public let channelCount: Int
    public let frameCount: Int64
    public let fileSize: Int64
    /// Encoded source format, not the decoder's floating-point working format.
    public let codec: String
    public let sourceBitDepth: Int?
    public init(filename: String, container: String, duration: Double, sampleRate: Double,
                channelCount: Int, frameCount: Int64, fileSize: Int64, codec: String, sourceBitDepth: Int?) {
        self.filename = filename; self.container = container; self.duration = duration
        self.sampleRate = sampleRate; self.channelCount = channelCount; self.frameCount = frameCount
        self.fileSize = fileSize; self.codec = codec; self.sourceBitDepth = sourceBitDepth
    }
}

public enum Feature: String, Codable, CaseIterable, Sendable {
    case bpm, key, chords, structure, tempoMap, stems, groove, transcription
}
public enum Availability: String, Codable, Sendable { case available, notImplemented }
public struct FeatureStatus: Codable, Sendable {
    public let feature: Feature
    public let availability: Availability
    public let reason: String
  
    public init(_ feature: Feature, _ availability: Availability, _ reason: String) {
        self.feature = feature; self.availability = availability; self.reason = reason
    }
}
public struct TimedChord: Codable, Sendable { public let start: Double; public let end: Double; public let symbol: String; public let confidence: Double
    public init(start: Double, end: Double, symbol: String, confidence: Double) { self.start = start; self.end = end; self.symbol = symbol; self.confidence = confidence } }
public struct SongSection: Codable, Sendable { public let start: Double; public let end: Double; public let label: String; public let confidence: Double
    public init(start: Double, end: Double, label: String, confidence: Double) { self.start = start; self.end = end; self.label = label; self.confidence = confidence } }
public struct TempoPoint: Codable, Sendable { public let seconds: Double; public let bpm: Double
    public init(seconds: Double, bpm: Double) { self.seconds = seconds; self.bpm = bpm } }
public struct Beat: Codable, Sendable { public let seconds: Double; public let confidence: Double
    public init(seconds: Double, confidence: Double) { self.seconds = seconds; self.confidence = confidence } }
public struct Onset: Codable, Sendable { public let seconds: Double; public let instrument: String; public let confidence: Double
    public init(seconds: Double, instrument: String, confidence: Double) { self.seconds = seconds; self.instrument = instrument; self.confidence = confidence } }
public struct TimingDeviation: Codable, Sendable {
    public let onsetSeconds: Double
    public let beatSeconds: Double
    /// Positive values mean the onset is later than the reference beat.
    public let offsetMilliseconds: Double
    public let instrument: String
  
    public init(onsetSeconds: Double, beatSeconds: Double, offsetMilliseconds: Double, instrument: String) {
        self.onsetSeconds = onsetSeconds; self.beatSeconds = beatSeconds
        self.offsetMilliseconds = offsetMilliseconds; self.instrument = instrument
    }
}
public struct AnalysisResult: Codable, Sendable {
    public let engine: String
    public let statuses: [FeatureStatus]
    public let bpm: Double?
    public let key: String?
    public let chords: [TimedChord]?
    public let sections: [SongSection]?
    public let tempoMap: [TempoPoint]?
    public let beats: [Beat]?
  
    public init(engine: String, statuses: [FeatureStatus], bpm: Double? = nil, key: String? = nil,
                chords: [TimedChord]? = nil, sections: [SongSection]? = nil,
                tempoMap: [TempoPoint]? = nil, beats: [Beat]? = nil) {
        self.engine = engine; self.statuses = statuses; self.bpm = bpm; self.key = key
        self.chords = chords; self.sections = sections; self.tempoMap = tempoMap; self.beats = beats
    }
}
public struct StemAsset: Sendable { public let instrument: String; public let url: URL
    public init(instrument: String, url: URL) { self.instrument = instrument; self.url = url } }
public struct MIDINote: Codable, Sendable { public let start: Double; public let duration: Double; public let pitch: UInt8; public let velocity: UInt8
    public init(start: Double, duration: Double, pitch: UInt8, velocity: UInt8) { self.start = start; self.duration = duration; self.pitch = pitch; self.velocity = velocity } }

public protocol AudioMetadataLoading: Sendable { func load(url: URL) throws -> AudioMetadata }
public protocol MusicAnalysisService: Sendable {
    var identifier: String { get }
    func analyze(url: URL, metadata: AudioMetadata) async throws -> AnalysisResult
}
public protocol StemSeparationService: Sendable { func separate(url: URL) async throws -> [StemAsset] }
public protocol MIDITranscriptionService: Sendable { func transcribe(url: URL) async throws -> [MIDINote] }
public protocol GrooveAnalysisService: Sendable {
    func analyze(beats: [Beat], onsets: [Onset]) async throws -> [TimingDeviation]
}

/// Intentionally returns no inferred musical results until a real engine is installed.
public struct UnavailableAnalysisService: MusicAnalysisService {
    public let identifier = "metadata-only/1.0"
  
    public init() {}
    public func analyze(url: URL, metadata: AudioMetadata) async throws -> AnalysisResult {
        try Task.checkCancellation()
        return AnalysisResult(engine: identifier, statuses: Feature.allCases.map {
            FeatureStatus($0, .notImplemented, "解析エンジン未接続")
        })
    }
}
