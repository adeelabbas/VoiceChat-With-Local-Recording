import UIKit
import Speech

///
/// --- AudioFileRecorder
///
let DefaultAudioSampleRate = 44100
let DefaultAudioNumberOfChannels = 1

class AudioFileRecorder {
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    
    private(set) public var firstTimeStamp: CMTime?
    
    func startRecording(fromFilePath: String) -> Bool {
        
        let audioFileURL = URL(fileURLWithPath: fromFilePath)
                    
        guard let assetWriter = try? AVAssetWriter(outputURL: audioFileURL, fileType: .m4a) else {
            log.error("Unable to instantiate AudioFileRecorder")
            return false
        }
        assetWriter.movieFragmentInterval = CMTime(seconds: 6, preferredTimescale: 600)
        
        let outputSettings = [
//            AVFormatIDKey: Int(kAudioFormatLinearPCM),
//            AVSampleRateKey: Int(DefaultAudioSampleRate),
//            AVNumberOfChannelsKey: Int(DefaultAudioNumberOfChannels),
//            AVLinearPCMBitDepthKey: 16,
//            AVLinearPCMIsBigEndianKey: 0,
//            AVLinearPCMIsFloatKey: 0,
//            AVLinearPCMIsNonInterleaved: 0,
            
            // Apple Lossless
//            AVFormatIDKey: Int(kAudioFormatAppleLossless),
//            AVSampleRateKey: Int(DefaultAudioSampleRate),
//            AVNumberOfChannelsKey: Int(DefaultAudioNumberOfChannels),
//            AVEncoderBitDepthHintKey: 16

            // AAC or M4A
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Int(DefaultAudioSampleRate),
            AVNumberOfChannelsKey: Int(DefaultAudioNumberOfChannels),
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        
        let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        assetWriterInput.expectsMediaDataInRealTime = true
        assetWriter.add(assetWriterInput)
        self.assetWriterInput = assetWriterInput
        
        self.assetWriter = assetWriter
        return true
    }
    
    func stopRecording(finishedHandler: ((URL) -> Void)? = nil) {
        
        guard let assetWriter = self.assetWriter else {
            log.error("Could not get assetWriter for audio")
            return
        }

        assetWriterInput?.markAsFinished()

        if assetWriter.status == .writing {
            
            assetWriter.finishWriting {
                log.info("Wrote \(assetWriter.outputURL.absoluteString)")
                if let finishedHandler = finishedHandler {
                    finishedHandler(assetWriter.outputURL)
                }
            }
        } else {
            log.error("AssetWriter is in \(assetWriter.status.rawValue) state: \(String(describing: assetWriter.error))")
        }
    }
    
    func recordAudioFrame(samplesPerChannel: Int, bytesPerSample: Int, frameTime: Double, audioFrameBuffer: UnsafeMutableRawPointer? ) -> Bool {
        
        var status: OSStatus

        let audioDataSize: Int = samplesPerChannel * bytesPerSample * DefaultAudioNumberOfChannels

        var asbd = AudioStreamBasicDescription(
            mSampleRate: Float64(DefaultAudioSampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: UInt32(DefaultAudioNumberOfChannels),
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        var audioFormatDescription: CMAudioFormatDescription?
        status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                asbd: &asbd,
                                                layoutSize: 0,
                                                layout: nil,
                                                magicCookieSize: 0,
                                                magicCookie: nil,
                                                extensions: nil,
                                                formatDescriptionOut: &audioFormatDescription)
        assert(status == noErr)
        
        var blockBuffer: CMBlockBuffer?
        status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                    memoryBlock: audioFrameBuffer,
                                                    blockLength: audioDataSize,
                                                    blockAllocator: kCFAllocatorNull,
                                                    customBlockSource: nil,
                                                    offsetToData: 0,
                                                    dataLength: audioDataSize,
                                                    flags: 0,
                                                    blockBufferOut: &blockBuffer)
        assert(status == kCMBlockBufferNoErr)
    
        
        guard let blockBuffer = blockBuffer else {
            return false
        }
        
        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: kCFAllocatorDefault,
                                                                      dataBuffer: blockBuffer,      // dataBuffer
                                                                      formatDescription: audioFormatDescription!,
                                                                      sampleCount: audioDataSize,    // numSamples
                                                                      presentationTimeStamp: CMTimeMakeWithSeconds(frameTime, preferredTimescale: Int32(DefaultAudioSampleRate)),    // sbufPTS
                                                                      packetDescriptions: nil,        // packetDescriptions
                                                                      sampleBufferOut: &sampleBuffer)
        assert(status == noErr)

        guard let sampleBuffer = sampleBuffer else {
            log.error("sampleBuffer is nil")
            return false
        }
        
        return recordAudioSample(sampleBuffer: sampleBuffer)
    }
    
    func recordAudioSample(sampleBuffer: CMSampleBuffer) -> Bool {
        guard let assetWriter = self.assetWriter,
              CMSampleBufferDataIsReady(sampleBuffer),
              let audioInput = self.assetWriterInput else {
                return false
        }

        if assetWriter.status == .unknown {
            assetWriter.startWriting()
            let firstTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            self.firstTimeStamp = firstTimeStamp
            
            assetWriter.startSession(atSourceTime: firstTimeStamp)
            log.info("Started recording audio with first timestamp \(firstTimeStamp.seconds)")
            
            if let formatDescription = sampleBuffer.formatDescription {
                let audioStreamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                
                if let audioStreamDescription = audioStreamDescription?.pointee {
                    log.info("mSampleRate = \(audioStreamDescription.mSampleRate) | mBitsPerChannel = \(audioStreamDescription.mBitsPerChannel) | mFormatFlags = \(audioStreamDescription.mFormatFlags) | mFormatID = \(audioStreamDescription.mFormatID) | mChannelsPerFrame = \(audioStreamDescription.mChannelsPerFrame) | mBitsPerChannel = \(audioStreamDescription.mBitsPerChannel)")
                }
            }
        }
        
        if assetWriter.status == .writing && audioInput.isReadyForMoreMediaData {
            
            if audioInput.append(sampleBuffer) == false  {
                log.error("audioInput.append failed. \(String(describing: assetWriter.error?.localizedDescription))")
                return false
            }
        }
        
        if assetWriter.status == .failed {
            log.error("audio assetWriter in error state. \(assetWriter.error.debugDescription)")
            return false
        }
        
        return true
    }
}
