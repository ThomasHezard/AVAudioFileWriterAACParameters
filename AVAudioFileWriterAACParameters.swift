#!/usr/bin/env swift

import Foundation
import CryptoKit
import AVFoundation

let keep_encoded_files = false

let input_file_path: String = "resources/Unity.wav"
let output_directory: String = "outputs"
let output_directory_url: URL = URL.init(fileURLWithPath:output_directory, isDirectory:true)
if FileManager.default.fileExists(atPath: output_directory) {
    try! FileManager.default.removeItem(atPath: output_directory)
}
try! FileManager.default.createDirectory(atPath: output_directory, withIntermediateDirectories: true, attributes: nil)

let processing_buffer_size: Int = 8192

print("Original file: \(input_file_path)")
let input_url = URL(fileURLWithPath:input_file_path)
var reader = try! AVAudioFile.init(forReading: input_url, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
print("Original file length: \(reader.length)\n")

// Prepare processing buffer
var buffer = AVAudioPCMBuffer.init(pcmFormat: reader.processingFormat, frameCapacity: AVAudioFrameCount(processing_buffer_size))

// Init results dictionary
var results: [[String: String]] = []

// Function: Get bitrate of file on disk using afinfo
func getBitrate(file_url: URL) -> Int {
    let task = Process()
    task.launchPath = "/bin/zsh/"
    task.arguments = ["-c", "afinfo \(file_url.path)"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = String(data: data, encoding: .utf8)!
    let lines = output.components(separatedBy: "\n")
    for line in lines {
        if line.contains("bit rate") {
            return Int(line.components(separatedBy: "bit rate: ")[1].components(separatedBy: " bits per second")[0])!
        }
    }
    // hard fail if we did not find the bit rate in afinfo output (this should never happen).
    assert(true)
    return -1
}

// Function: MD5 checksum of file
extension URL {
    func checksumInBase64() -> String {
        let bufferSize = 16*1024
        // Open file for reading:
        let file = try! FileHandle(forReadingFrom: self)
        defer {
            file.closeFile()
        }
        // Create and initialize MD5 context:
        var md5 = CryptoKit.Insecure.MD5()
        // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if data.count > 0 {
                md5.update(data: data)
                return true // Continue
            } else {
                return false // End of file
            }
        }) { }
        // Compute the MD5 digest:
        let data = Data(md5.finalize())
        return data.base64EncodedString()
    }
}

// Dunction: Decode file into standard AIFF
func decode(input_url: URL, output_url: URL) {
    
    print("Decode file into \(output_url.absoluteString)")
    let local_reader = try! AVAudioFile.init(forReading: input_url, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
    let settings: [String : Any] = [AVFormatIDKey: kAudioFormatLinearPCM,
                                  AVSampleRateKey: local_reader.processingFormat.sampleRate,
                            AVNumberOfChannelsKey: local_reader.processingFormat.channelCount,
                           AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsBigEndianKey: true]
    
    let writer = try! AVAudioFile.init(
        forWriting: output_url,
        settings: settings,
        commonFormat:AVAudioCommonFormat.pcmFormatFloat32,
        interleaved: false)
    while local_reader.framePosition < local_reader.length {
        buffer!.frameLength = 0
        try! local_reader.read(into: buffer!)
        try! writer.write(from: buffer!)
    }
    print("✅ Frames decoded: \(writer.length)")
}

// Function: Main process for a given settings dictionary: encode, decode and write analytics in results dictionnary
func process(settings: [String : Any], output_url: URL) {

    reader.framePosition = 0
    print("Encode file into \(output_url.absoluteString) with settings:")
    print("\(settings)")
    let aiff_url = output_url.deletingPathExtension().appendingPathExtension("aiff")
    var success: Bool = false
    var conversion_time = 0
    do {
        let writer = try AVAudioFile.init(
            forWriting: output_url,
            settings: settings,
            commonFormat:AVAudioCommonFormat.pcmFormatFloat32,
            interleaved: false)
        let start = DispatchTime.now()
        while reader.framePosition < reader.length {
            buffer!.frameLength = 0
            try! reader.read(into: buffer!)
            try! writer.write(from: buffer!)
        }
        let end = DispatchTime.now()
        conversion_time = Int(end.uptimeNanoseconds - start.uptimeNanoseconds)
        print("✅ Frames written: \(writer.length)")
        success = true
    } catch {
        print("❌ Incompatible settings")
    }

    if (success) {
        decode(input_url: output_url, output_url: aiff_url)
    }
    
    let bitrate: Int = success ? getBitrate(file_url: output_url) : -1
    let md5: String = success ? output_url.checksumInBase64() : ""
    let aiff_md5: String = success ? aiff_url.checksumInBase64() : ""

    var result: [String : String] = [:]
    if settings.keys.contains(AVSampleRateKey) {
        result["SampleRate"] = String(settings[AVSampleRateKey] as! Double)
    }
    if settings.keys.contains(AVNumberOfChannelsKey) {
        result["NumberOfChannels"] = String(settings[AVNumberOfChannelsKey] as! UInt32)
    }
    if settings.keys.contains(AVEncoderBitRateStrategyKey) {
        result["Strategy"] = (settings[AVEncoderBitRateStrategyKey] as! String)
    }
    if settings.keys.contains(AVEncoderBitRateKey) {
        result["BitRate"] = String(settings[AVEncoderBitRateKey] as! Int)
    }
    if settings.keys.contains(AVEncoderBitRatePerChannelKey) {
        result["BitRatePerChannel"] = String(settings[AVEncoderBitRatePerChannelKey] as! Int)
    }
    if settings.keys.contains(AVEncoderAudioQualityKey) {
        result["Quality"] = String((settings[AVEncoderAudioQualityKey] as! AVAudioQuality).rawValue)
    }
    if settings.keys.contains(AVEncoderAudioQualityForVBRKey) {
        result["VBRQuality"] = String((settings[AVEncoderAudioQualityForVBRKey] as! AVAudioQuality).rawValue)
    }
    result["MeasuredBitRate"] = String(bitrate)
    result["ConversionTimeNanoSeconds"] = String(conversion_time)
    result["MD5"] = md5
    result["AIFFMD5"] = aiff_md5
    result["FileFormat"] = output_url.pathExtension

    results.append(result)
    
    if (!keep_encoded_files) {
        try! FileManager.default.removeItem(at: output_url)
    }
    if (success) {
        try! FileManager.default.removeItem(at: aiff_url)
    }

    print("\n***\n")
}


for ext in ["caf", "m4a"] {
    for strategy in [AVAudioBitRateStrategy_Constant,
                     AVAudioBitRateStrategy_LongTermAverage,
                     AVAudioBitRateStrategy_VariableConstrained,
                     AVAudioBitRateStrategy_Variable] {

        // defaut quality, default bitrate,
        do {
            var settings = [:] as [String : Any]
            settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                      AVSampleRateKey: reader.processingFormat.sampleRate,
                AVNumberOfChannelsKey: reader.processingFormat.channelCount,
          AVEncoderBitRateStrategyKey: strategy]
            let index = strategy.index(strategy.startIndex, offsetBy: 23)
            let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...]).\(ext)")
            process(settings: settings, output_url: output_url)
        }

        for quality in [AVAudioQuality.min, AVAudioQuality.low, AVAudioQuality.medium, AVAudioQuality.high, AVAudioQuality.max] {

            // default bitrate
            do {
                reader.framePosition = 0
                var settings = [:] as [String : Any]
                settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                          AVSampleRateKey: reader.processingFormat.sampleRate,
                    AVNumberOfChannelsKey: reader.processingFormat.channelCount,
              AVEncoderBitRateStrategyKey: strategy,
                 AVEncoderAudioQualityKey: quality]
                let index = strategy.index(strategy.startIndex, offsetBy: 23)
                let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_Q\(quality.rawValue).\(ext)")
                process(settings: settings, output_url: output_url)
            }
        }

        if (strategy != AVAudioBitRateStrategy_Variable) {// ⚠️ Non-catchable crash for these settings with "Variable" strategy
            for vbr_quality in [AVAudioQuality.min, AVAudioQuality.low, AVAudioQuality.medium, AVAudioQuality.high, AVAudioQuality.max] {

                // default bitrate
                do {
                    reader.framePosition = 0
                    var settings = [:] as [String : Any]
                    settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                              AVSampleRateKey: reader.processingFormat.sampleRate,
                        AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                  AVEncoderBitRateStrategyKey: strategy,
               AVEncoderAudioQualityForVBRKey: vbr_quality]
                    let index = strategy.index(strategy.startIndex, offsetBy: 23)
                    let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_VBRQ\(vbr_quality.rawValue).\(ext)")
                    process(settings: settings, output_url: output_url)
                }
            }
        }

        for bit_rate in [32000, 64000, 96000, 128000, 192000, 320000] {

            // defaut quality, bit rate set with AVEncoderBitRateKey
            do {
                reader.framePosition = 0
                var settings = [:] as [String : Any]
                settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                          AVSampleRateKey: reader.processingFormat.sampleRate,
                    AVNumberOfChannelsKey: reader.processingFormat.channelCount,
              AVEncoderBitRateStrategyKey: strategy,
                      AVEncoderBitRateKey: bit_rate]
                let index = strategy.index(strategy.startIndex, offsetBy: 23)
                let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_BR\(bit_rate).\(ext)")
                process(settings: settings, output_url: output_url)
            }

            // defaut quality, bit rate set with AVEncoderBitRatePerChannelKey
            do {
                reader.framePosition = 0
                var settings = [:] as [String : Any]
                settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                          AVSampleRateKey: reader.processingFormat.sampleRate,
                    AVNumberOfChannelsKey: reader.processingFormat.channelCount,
              AVEncoderBitRateStrategyKey: strategy,
            AVEncoderBitRatePerChannelKey: bit_rate]
                let index = strategy.index(strategy.startIndex, offsetBy: 23)
                let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_BRPC\(bit_rate).\(ext)")
                process(settings: settings, output_url: output_url)
            }


            for quality in [AVAudioQuality.min, AVAudioQuality.low, AVAudioQuality.medium, AVAudioQuality.high, AVAudioQuality.max] {

                // bit rate set with AVEncoderBitRateKey
                do {
                    reader.framePosition = 0
                    var settings = [:] as [String : Any]
                    settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                              AVSampleRateKey: reader.processingFormat.sampleRate,
                        AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                  AVEncoderBitRateStrategyKey: strategy,
                          AVEncoderBitRateKey: bit_rate,
                     AVEncoderAudioQualityKey: quality]
                    let index = strategy.index(strategy.startIndex, offsetBy: 23)
                    let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_BR\(bit_rate)_Q\(quality.rawValue).\(ext)")
                    process(settings: settings, output_url: output_url)
                }

                // bit rate set with AVEncoderBitRatePerChannelKey
                do {
                    reader.framePosition = 0
                    var settings = [:] as [String : Any]
                    settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                              AVSampleRateKey: reader.processingFormat.sampleRate,
                        AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                  AVEncoderBitRateStrategyKey: strategy,
                AVEncoderBitRatePerChannelKey: bit_rate,
                     AVEncoderAudioQualityKey: quality]
                    let index = strategy.index(strategy.startIndex, offsetBy: 23)
                    let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_BRPC\(bit_rate)_Q\(quality.rawValue).\(ext)")
                    process(settings: settings, output_url: output_url)
                }
            }

            if (strategy != AVAudioBitRateStrategy_Variable) {// ⚠️ Non-catchable crash for these settings with "Variable" strategy
                for vbr_quality in [AVAudioQuality.min, AVAudioQuality.low, AVAudioQuality.medium, AVAudioQuality.high, AVAudioQuality.max] {

                    // bit rate set with AVEncoderBitRateKey
                    do {
                        reader.framePosition = 0
                        var settings = [:] as [String : Any]
                        settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                  AVSampleRateKey: reader.processingFormat.sampleRate,
                            AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                      AVEncoderBitRateStrategyKey: strategy,
                              AVEncoderBitRateKey: bit_rate,
                   AVEncoderAudioQualityForVBRKey: vbr_quality]
                        let index = strategy.index(strategy.startIndex, offsetBy: 23)
                        let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_BR\(bit_rate)_VBRQ\(vbr_quality.rawValue).\(ext)")
                        process(settings: settings, output_url: output_url)
                    }

                    // bit rate set with AVEncoderBitRatePerChannelKey
                    do {
                        reader.framePosition = 0
                        var settings = [:] as [String : Any]
                        settings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                  AVSampleRateKey: reader.processingFormat.sampleRate,
                            AVNumberOfChannelsKey: reader.processingFormat.channelCount,
                      AVEncoderBitRateStrategyKey: strategy,
                    AVEncoderBitRatePerChannelKey: bit_rate,
                   AVEncoderAudioQualityForVBRKey: vbr_quality]
                        let index = strategy.index(strategy.startIndex, offsetBy: 23)
                        let output_url = output_directory_url.appendingPathComponent("Unity_\(strategy[index...])_BRPC\(bit_rate)_VBRQ\(vbr_quality.rawValue).\(ext)")
                        process(settings: settings, output_url: output_url)
                    }
                }
            }
        }
    }
}


// Function: remove duplicates from a sequence
extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}

// Analysis of results: AVAudioBitRateStrategy_Variable
do {
    var mbr_values: [String] = []
    results.filter({$0["Strategy"] == "AVAudioBitRateStrategy_Variable"}).forEach { item in
        mbr_values.append(item["MeasuredBitRate"]!)
    }
    print("Variable strategy, any bitrate, any quality => measured bit rate values are \(mbr_values.unique())")
}

// Analysis of results: BitRate 320000 
do {
    var mbr_values: [String] = []
    results.filter({$0["BitRate"] == "32000" && $0["Strategy"] != "AVAudioBitRateStrategy_Variable"}).forEach { item in
        mbr_values.append(item["MeasuredBitRate"]!)
    }
    print("BitRate 32000, any strategy except Variable, any quality => measured bit rate values are \(mbr_values.unique())")
}

// Analysis of results: BitRatePerChannel
["AVAudioBitRateStrategy_Constant", "AVAudioBitRateStrategy_LongTermAverage", "AVAudioBitRateStrategy_VariableConstrained"].forEach { strategy in
    var mbr_values: [String] = []
    results.filter({$0["BitRatePerChannel"] != nil && $0["Strategy"] == strategy}).forEach { item in
        mbr_values.append(item["MeasuredBitRate"]!)
    }
    print("BitRatePerChannel with any value, \(strategy), any quality => measured bit rate values are \(mbr_values.unique())")
}

// Analysis of results: other cases 
["AVAudioBitRateStrategy_Constant", "AVAudioBitRateStrategy_LongTermAverage", "AVAudioBitRateStrategy_VariableConstrained"].forEach { strategy in
    ["64000", "96000", "128000", "192000", "320000"].forEach { bitrate in
        var mbr_values: [String] = []
        var caf_sha_values: [String] = []
        var caf_decoded_sha_values: [String] = []
        var m4a_sha_values: [String] = []
        var m4a_decoded_sha_values: [String] = []
        results.filter({$0["BitRate"] == bitrate && $0["Strategy"] == strategy}).forEach { item in
            mbr_values.append(item["MeasuredBitRate"]!)
            if (item["FileFormat"] == "caf") {
                caf_sha_values.append(item["MD5"]!)
                caf_decoded_sha_values.append(item["AIFFMD5"]!)
            } else {
                m4a_sha_values.append(item["MD5"]!)
                m4a_decoded_sha_values.append(item["AIFFMD5"]!)
            }
        }
        print("\(strategy), Bitrate \(bitrate), any quality => ")
        print("  - measured bit rate values are \(mbr_values.unique()),")
        print("  - caf files are identical: \(caf_sha_values.unique().count == 1 ? "yes" : "no")")
        print("  - caf audio content are identical: \(caf_decoded_sha_values.unique().count == 1 ? "yes" : "no")")
        print("  - m4a files are identical: \(m4a_sha_values.unique().count == 1 ? "yes" : "no")")
        print("  - m4a audio content are identical: \(m4a_decoded_sha_values.unique().count == 1 ? "yes" : "no")")
    }
}
