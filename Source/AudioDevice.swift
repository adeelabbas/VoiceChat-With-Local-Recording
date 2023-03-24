
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
