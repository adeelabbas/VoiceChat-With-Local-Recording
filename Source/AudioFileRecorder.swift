import UIKit
import Speech

///
/// --- AudioFileRecorder
///
let DefaultAudioSampleRate = 16000
let DefaultAudioNumberOfChannels = 1

class AudioFileRecorder {
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    
    private(set) public var firstTimeStamp: CMTime?
    
    func startRecording(fromFilePath: String) -> Bool {
        
        let audioFileURL = URL(fileURLWithPath: fromFilePath)
                    
        guard let assetWriter = try? AVAssetWriter(outputURL: audioFileURL, fileType: .wav) else {
            log.error("Unable to instantiate AudioFileRecorder")
            return false
        }
        assetWriter.movieFragmentInterval = CMTime(seconds: 6, preferredTimescale: 600)
        
        let outputSettings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: Int(DefaultAudioSampleRate),
            AVNumberOfChannelsKey: Int(DefaultAudioNumberOfChannels),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: 0,
            AVLinearPCMIsFloatKey: 0,
            AVLinearPCMIsNonInterleaved: 0,
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
