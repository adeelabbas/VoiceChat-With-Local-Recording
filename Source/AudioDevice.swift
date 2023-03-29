
import AVFoundation

class AudioDevice : NSObject {
    
    private var captureSession: AVCaptureSession?
    
    private let audioQueue = DispatchQueue(label: "Audio Device Session Queue")
    
    private let audioDataOutput = AVCaptureAudioDataOutput()
    
    init(   captureSession: AVCaptureSession?,
            audioSampleBufferDelegate: AVCaptureAudioDataOutputSampleBufferDelegate? ) {
        
        self.captureSession = captureSession
        
        super.init()
                
        audioDataOutput.setSampleBufferDelegate(audioSampleBufferDelegate, queue: audioQueue)
    }
    
    static func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        let category = audioSession.category
        let mode = audioSession.mode
                
        if audioSession.category != .playAndRecord || audioSession.mode != .videoChat {
            do {
                let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
                try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: options)
                try audioSession.setPrefersNoInterruptionsFromSystemAlerts(true)
                try audioSession.setPreferredSampleRate(Double(44100))
                try audioSession.setActive(true)
                
                log.info("Changing audio mode/category from \(mode.rawValue)/\(category.rawValue) to videoChat/playAndRecord")
            } catch {
                log.error("error while calling setupAudioSession")
            }
        }
    }
    
    func configureAudio() -> Bool {
        
        guard let captureSession = self.captureSession else {
            log.error("Could not get session")
            return false
        }
        
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.audio) else {
            log.error("Unable to setup capture device for audio")
            return false
        }

        do {
//            try captureDevice.lockForConfiguration()
            let audioInput = try AVCaptureDeviceInput(device: captureDevice)
//            captureDevice.unlockForConfiguration()
                        
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            } else {
                log.error("Cannot add input")
                return false
            }
            if captureSession.canAddOutput(self.audioDataOutput) {
                captureSession.addOutput(self.audioDataOutput)
            } else {
                log.error("cannot add output")
                return false
            }

            log.error("Starting audio capture session")
            return true
        } catch {
            log.error("Capture devices could not be set. Error = \(error.localizedDescription)")
            return false
        }
    }
}
