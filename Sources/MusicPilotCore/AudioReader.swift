import Foundation
import AVFoundation
import AudioToolbox

public enum MusicPilotError: LocalizedError {
    case invalidAudio, invalidTempo
    public var errorDescription: String? {
        switch self {
        case .invalidAudio: return "音声を読み込めませんでした。破損していないWAV、MP3、AIFF、M4A、CAFなどを選んでください。"
        case .invalidTempo: return "テンポは20〜300 BPMの範囲で入力してください。"
        }
    }
}
public struct AVAudioMetadataReader: AudioMetadataLoading {
    public init() {}
    public func load(url: URL) throws -> AudioMetadata {
        guard url.isFileURL else { throw MusicPilotError.invalidAudio }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw MusicPilotError.invalidAudio }
        let file = try AVAudioFile(forReading: url)
        let source = file.fileFormat.streamDescription.pointee
        let rate = file.processingFormat.sampleRate
        guard rate.isFinite, rate > 0, file.length > 0, file.processingFormat.channelCount > 0 else {
            throw MusicPilotError.invalidAudio
        }
        let format = source.mFormatID
        let codec: String
        switch format {
        case kAudioFormatLinearPCM: codec = "PCM"
        case kAudioFormatMPEGLayer3: codec = "MP3"
        case kAudioFormatMPEG4AAC: codec = "AAC"
        case kAudioFormatAppleLossless: codec = "Apple Lossless"
        default:
            let bytes = [24,16,8,0].map { UInt8((format >> $0) & 255) }
            codec = String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? "Unknown"
        }
        return AudioMetadata(filename: url.lastPathComponent, container: url.pathExtension.uppercased(),
                             duration: Double(file.length) / rate, sampleRate: rate,
                             channelCount: Int(file.processingFormat.channelCount), frameCount: file.length,
                             fileSize: Int64(values.fileSize ?? 0), codec: codec,
                             sourceBitDepth: source.mBitsPerChannel > 0 ? Int(source.mBitsPerChannel) : nil)
    }
}
