import Foundation

public struct AnalysisDocument: Codable, Sendable {
    public let schemaVersion: Int
    public let application: String
    public let exportedAt: Date
    public let audio: AudioMetadata
    public let analysis: AnalysisResult
    public let referenceTempo: Double
    public let referenceTempoSource: String
    public init(audio: AudioMetadata, analysis: AnalysisResult, referenceTempo: Double) {
        schemaVersion = 1; application = "MusicPilot 1.0.0"; exportedAt = Date()
        self.audio = audio; self.analysis = analysis; self.referenceTempo = referenceTempo
        referenceTempoSource = "user-entered; not detected from audio"
    }
}
public enum ExportService {
    public static func json(_ document: AnalysisDocument) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }
    public static func csv(_ document: AnalysisDocument) -> Data {
        let m = document.audio
        let rows: [[String]] = [
            ["field", "value", "source"],
            ["filename", m.filename, "file"], ["duration_seconds", String(m.duration), "decoded frame count"],
            ["sample_rate_hz", String(m.sampleRate), "audio metadata"],
            ["channels", String(m.channelCount), "audio metadata"],
            ["codec", m.codec, "audio metadata"],
            ["source_bit_depth", m.sourceBitDepth.map(String.init) ?? "unknown", "audio metadata"],
            ["file_size_bytes", String(m.fileSize), "filesystem"],
            ["reference_tempo_bpm", String(document.referenceTempo), document.referenceTempoSource]
        ] + document.analysis.statuses.map { [$0.feature.rawValue, $0.availability.rawValue, $0.reason] }
        // Quote every field; escape spreadsheet formula prefixes on textual fields.
        let content = rows.map { row in row.map { field -> String in
            let safe = field.first.map { "=+-@\t\r\n".contains($0) } == true ? "'" + field : field
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data(content.utf8)
    }
    /// SMF format 0: tempo, 4/4 time signature, and explicit provenance. No transcribed notes.
    public static func referenceTempoMIDI(bpm: Double) throws -> Data {
        guard bpm.isFinite, (20...300).contains(bpm) else { throw MusicPilotError.invalidTempo }
        let tempo = Int((60_000_000 / bpm).rounded())
        let label = Array("MusicPilot manual reference tempo (not audio transcription)".utf8)
        var track: [UInt8] = [0, 0xFF, 0x03, UInt8(label.count)] + label
        track += [0, 0xFF, 0x51, 3, UInt8((tempo >> 16) & 255), UInt8((tempo >> 8) & 255), UInt8(tempo & 255)]
        track += [0, 0xFF, 0x58, 4, 4, 2, 24, 8, 0, 0xFF, 0x2F, 0]
        let n = UInt32(track.count)
        return Data(Array("MThd".utf8) + [0,0,0,6,0,0,0,1,1,0xE0] + Array("MTrk".utf8) +
                    [UInt8((n >> 24) & 255), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)] + track)
    }
}
