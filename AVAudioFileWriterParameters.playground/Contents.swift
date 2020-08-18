import Cocoa
import AVFoundation

var input_url = Bundle.main.url(forResource:"Unity", withExtension: "wav")
var reader = try! AVAudioFile.init(forReading: input_url!, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
print("Original file length: \(reader.length)\n")

var buffer = AVAudioPCMBuffer.init(pcmFormat: reader.processingFormat, frameCapacity: 1024)

for bit_rate_per_channel in [16, 32, 48, 64, 96, 128] {
    for strategy in [AVAudioBitRateStrategy_Constant,
                     AVAudioBitRateStrategy_LongTermAverage,
                     AVAudioBitRateStrategy_VariableConstrained,
                     AVAudioBitRateStrategy_Variable]
    {
        for quality in [AVAudioQuality.min, AVAudioQuality.low, AVAudioQuality.medium, AVAudioQuality.high, AVAudioQuality.max] {
            for ext in ["caf", "m4a"] {
                reader.framePosition = 0
                var settings = [:] as [String : Any]
                if (strategy == AVAudioBitRateStrategy_Variable || strategy == AVAudioBitRateStrategy_VariableConstrained) {
                    settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                AVSampleRateKey: reader.processingFormat.sampleRate,
                                AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                                AVEncoderBitRateStrategyKey: strategy,
                                AVEncoderBitRatePerChannelKey: bit_rate_per_channel,
                                AVEncoderAudioQualityForVBRKey: quality,
                                AVEncoderBitDepthHintKey: 16] as [String : Any]
                } else {
                    settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                AVSampleRateKey: reader.processingFormat.sampleRate,
                                AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                                AVEncoderBitRateStrategyKey: strategy,
                                AVEncoderBitRatePerChannelKey: bit_rate_per_channel,
                                AVEncoderAudioQualityKey: quality,
                                AVEncoderBitDepthHintKey: 16] as [String : Any]
                }
                let output_url = input_url!.deletingLastPathComponent().appendingPathComponent("Unity_BRPC\(bit_rate_per_channel)_\(strategy)_Q\(quality.rawValue).\(ext)")
                let writer = try! AVAudioFile.init(forWriting: output_url, settings: settings, commonFormat:AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
                
                while reader.framePosition < reader.length {
                    buffer!.frameLength = 0
                    try! reader.read(into: buffer!)
                    try! writer.write(from: buffer!)
                }
                
                let attr = try! FileManager.default.attributesOfItem(atPath:output_url.path)
                
                print("Output file: \(output_url.path)")
                print("Bit rate: \(bit_rate_per_channel)")
                print("strategy: \(strategy)")
                print("quality: \(quality)")
                print("frames written: \(writer.length)")
                print("file extension: \(ext)")
                print("=> resulting file size: \(attr[FileAttributeKey.size] as! UInt64)\n")
            }
        }
    }
}
