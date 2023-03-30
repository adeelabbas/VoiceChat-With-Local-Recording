
import UIKit
import AgoraRtcKit
import AGEVideoLayout
import Loggerithm
import AVFoundation

var log = Loggerithm()

/// Helper Functions
///

func getAudioFilePath(audioFileExtension: String) -> String
{
    do {
        let fileURL = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(getFileBaseName()).appendingPathExtension(audioFileExtension)
        return fileURL.path
        
    } catch {
        return ""
    }
}

func getFileBaseName() -> String {
    let now = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd'T'HHmmss"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: now)
}

func fileExists(file: String) -> Bool {
    return FileManager.default.fileExists(atPath: file)
}

func deleteFile(filePath: String) -> Bool {
    if fileExists(file: filePath) {

        do {
            try FileManager.default.removeItem(atPath: filePath)
            return true
        } catch {
            NSLog("Could not remove file at url: \(filePath)")
            return false
        }
    } else {
        return false
    }
}
///

class JoinChannelAudioEntry : UIViewController
{
    @IBOutlet weak var joinButton: AGButton!
    @IBOutlet weak var channelTextField: AGTextField!

    let identifier = "JoinChannelAudio"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        log.showDateTime = false
        log.showFunctionName = false
    }
    @IBAction func CrashButton(_ sender: Any) {
        fatalError()
    }
    
    @IBAction func doJoinPressed(sender: AGButton) {
        guard let channelName = channelTextField.text else {return}
        //resign channel text field
        channelTextField.resignFirstResponder()
        
        let storyBoard: UIStoryboard = UIStoryboard(name: identifier, bundle: nil)
        // create new view controller every time to ensure we get a clean vc
        guard let newViewController = storyBoard.instantiateViewController(withIdentifier: identifier) as? BaseViewController else {return}
        newViewController.title = channelName
        newViewController.configs = ["channelName":channelName]
        NetworkManager.shared.generateToken(channelName: channelName, uid: 0) {
            self.navigationController?.pushViewController(newViewController, animated: true)            
        }
    }
}

class JoinChannelAudioMain: BaseViewController {
    
    func alertBox(title : String, message : String, showLogExport: Bool = true) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        DispatchQueue.main.async { [weak self] in
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            
            self?.present(alert, animated: true)
        }
    }
    
    // -- Apple local recording
    var appleAudioFilePath = ""
    var appleAudioFileRecorder : AudioFileRecorder?
    func startAppleLocalRecording(recordedFilePath: String) {
        
        // Check if file already exists
        if fileExists(file: recordedFilePath) {
            log.info("deleted file at \(recordedFilePath)")
            _ = deleteFile(filePath: recordedFilePath)
        }

        self.appleAudioFilePath = recordedFilePath
        
        self.appleAudioFileRecorder = AudioFileRecorder()
        if let appleAudioFileRecorder = self.appleAudioFileRecorder {
            _ = appleAudioFileRecorder.startRecording(fromFilePath: recordedFilePath)
        }
    }
    
    func stopAppleLocalRecording() {

        if let appleAudioFileRecorder = self.appleAudioFileRecorder {
            appleAudioFileRecorder.stopRecording()
        }

        if !fileExists(file: self.appleAudioFilePath) {
            alertBox(title: "File was not recorded", message: self.appleAudioFilePath)
        }
        
        self.appleAudioFilePath = ""
        self.appleAudioFileRecorder = nil
    }
    
    // -- Audio recording
    var audioIsRecorded = true // Initial toggle will make it false
    func ToggleAudioIsRecorded(firsttime: Bool) {
        self.audioIsRecorded = !self.audioIsRecorded
        
        if !firsttime {
            if audioIsRecorded {
                self.startAppleLocalRecording(recordedFilePath: getAudioFilePath(audioFileExtension: "wav" ))
                
            } else {
                self.stopAppleLocalRecording()
            }
        }
        
        if self.audioIsRecorded {
            audioRecordButton.title = "stop recording"
            audioRecordButton.backgroundColor = .lightGray
        } else {
            audioRecordButton.title = "start recording"
            audioRecordButton.backgroundColor = .white
        }
    }
    @IBOutlet weak var audioRecordButton: UIButton!
    @IBAction func audioRecordButtonPressed(_ sender: Any) {
        ToggleAudioIsRecorded(firsttime: false)
    }
    // -- Audio recording
    
    var agoraKit: AgoraRtcEngineKit!
    @IBOutlet weak var container: AGEVideoContainer!
        
    var audioViews: [UInt:VideoView] = [:]
    
    // indicate if current instance has joined channel
    var isJoined: Bool = false

    override func viewDidLoad(){
        super.viewDidLoad()
                
        DispatchQueue(label: "Audio Session Queue").async {

            guard let channelName = self.configs["channelName"] as? String
                else { return }

            // set up agora instance when view loaded
            let config = AgoraRtcEngineConfig()
            config.appId = KeyCenter.AppId
            config.areaCode = .global
            config.channelProfile = .communication
            // set audio scenario
            config.audioScenario = .default
            self.agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
            self.agoraKit.setLogFile(LogUtils.sdkLogPath())
            
            // make myself a broadcaster
            self.agoraKit.setClientRole(.broadcaster)
            
            // disable video module
            self.agoraKit.disableVideo()
            
            self.agoraKit.enableAudio()
            
            // set audio profile, scenario and restriction
            self.agoraKit.setAudioProfile(.default)
            self.agoraKit.setAudioScenario(.default)
            self.agoraKit.setAudioFrameDelegate(self)
            
            // Set audio route to speaker
            self.agoraKit.setDefaultAudioRouteToSpeakerphone(true)
            
            // enable volume indicator
//            self.agoraKit.enableAudioVolumeIndication(200, smooth: 3, reportVad: true)
            
            // start joining channel
            // 1. Users can only see each other after they join the
            // same channel successfully using the same app id.
            // 2. If app certificate is turned on at dashboard, token is needed
            // when joining channel. The channel name and uid used to calculate
            // the token has to match the ones used for channel join
            let option = AgoraRtcChannelMediaOptions()
            option.publishCameraTrack = false
            option.publishMicrophoneTrack = true
            option.clientRoleType = .broadcaster
            
            let result = self.agoraKit.joinChannel(byToken: KeyCenter.Token, channelId: channelName, uid: 0, mediaOptions: option)
            if result != 0 {
                // Usually happens with invalid parameters
                // Error code description can be found at:
                // en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
                // cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
                self.showAlert(title: "Error", message: "joinChannel call failed: \(result), please check your params")
            }
            
            self.ToggleAudioIsRecorded(firsttime: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        agoraKit.enable(inEarMonitoring: false)
        agoraKit.disableAudio()
        agoraKit.disableVideo()
        if isJoined {
            agoraKit.leaveChannel { (stats) -> Void in
                LogUtils.log(message: "left channel, duration: \(stats.duration)", level: .info)
            }
        }
    }
    
    func sortedViews() -> [VideoView] {
        return Array(audioViews.values).sorted(by: { $0.uid < $1.uid })
    }
}

/// agora rtc engine delegate events
extension JoinChannelAudioMain: AgoraRtcEngineDelegate {
    /// callback when warning occured for agora sdk, warning can usually be ignored, still it's nice to check out
    /// what is happening
    /// Warning code description can be found at:
    /// en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraWarningCode.html
    /// @param warningCode warning code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        LogUtils.log(message: "warning: \(warningCode.description)", level: .warning)
    }
    
    /// callback when error occured for agora sdk, you are recommended to display the error descriptions on demand
    /// to let user know something wrong is happening
    /// Error code description can be found at:
    /// en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
    /// cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
    /// @param errorCode error code of the problem
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        LogUtils.log(message: "error: \(errorCode)", level: .error)
        self.showAlert(title: "Error", message: "Error \(errorCode.description) occur")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.isJoined = true
        LogUtils.log(message: "Join \(channel) with uid \(uid) elapsed \(elapsed)ms", level: .info)
        
        //set up local audio view, this view will not show video but just a placeholder
        let view = Bundle.loadVideoView(type: .local, audioOnly: true)
        self.audioViews[0] = view
        view.setPlaceholder(text: self.getAudioLabel(uid: uid, isLocal: true))
        self.container.layoutStream3x2(views: self.sortedViews())
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        LogUtils.log(message: "remote user join: \(uid) \(elapsed)ms", level: .info)

        //set up remote audio view, this view will not show video but just a placeholder
        let view = Bundle.loadVideoView(type: .remote, audioOnly: true)
        view.uid = uid
        self.audioViews[uid] = view
        view.setPlaceholder(text: self.getAudioLabel(uid: uid, isLocal: false))
        self.container.layoutStream3x2(views: sortedViews())
        self.container.reload(level: 0, animated: true)
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        LogUtils.log(message: "remote user left: \(uid) reason \(reason)", level: .info)
        
        //remove remote audio view
        self.audioViews.removeValue(forKey: uid)
        self.container.layoutStream3x2(views: sortedViews())
        self.container.reload(level: 0, animated: true)
    }
    
    /// Reports which users are speaking, the speakers' volumes, and whether the local user is speaking.
    /// @params speakers volume info for all speakers
    /// @params totalVolume Total volume after audio mixing. The value range is [0,255].
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
//        for speaker in speakers {
//            if let audioView = audioViews[speaker.uid] {
//                audioView.setInfo(text: "Volume:\(speaker.volume)")
//            }
//        }
    }
    
    /// Reports the statistics of the current call. The SDK triggers this callback once every two seconds after the user joins the channel.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportRtcStats stats: AgoraChannelStats) {
        audioViews[0]?.statsInfo?.updateChannelStats(stats)
    }
    
    /// Reports the statistics of the uploading local audio streams once every two seconds.
    /// @param stats stats struct
    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioStats stats: AgoraRtcLocalAudioStats) {
        audioViews[0]?.statsInfo?.updateLocalAudioStats(stats)
    }
    
    /// Reports the statistics of the audio stream from each remote user/host.
    /// @param stats stats struct for current call statistics
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStats stats: AgoraRtcRemoteAudioStats) {
        audioViews[stats.uid]?.statsInfo?.updateAudioStats(stats)
    }
}

extension JoinChannelAudioMain: AgoraAudioFrameDelegate {
    func onEarMonitoringAudioFrame(_ frame: AgoraAudioFrame) -> Bool {
        true
    }
    
    func getEarMonitoringAudioParams() -> AgoraAudioParams {
        AgoraAudioParams()
    }
    
    func getMixedAudioParams() -> AgoraAudioParams {
        AgoraAudioParams()
    }
    
    func getRecordAudioParams() -> AgoraAudioParams {
        let agoraAudioParams = AgoraAudioParams()
        agoraAudioParams.channel = DefaultAudioNumberOfChannels
        agoraAudioParams.sampleRate = DefaultAudioSampleRate
        agoraAudioParams.mode = .readOnly
        agoraAudioParams.samplesPerCall = 1024
        return agoraAudioParams
    }
    
    func getPlaybackAudioParams() -> AgoraAudioParams {
        AgoraAudioParams()
    }

    func onRecordAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        if audioIsRecorded {
            
            // Handle recording
            let audioDataSize: Int = frame.samplesPerChannel * frame.bytesPerSample

            var asbd = AudioStreamBasicDescription(
                mSampleRate: Float64(DefaultAudioSampleRate),
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved,
                mBytesPerPacket: 2,
                mFramesPerPacket: 1,
                mBytesPerFrame: 2,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 16,
                mReserved: 0
            )

            var audioFormatDescription: CMAudioFormatDescription?
            var status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                        asbd: &asbd,
                                                        layoutSize: 0,
                                                        layout: nil,
                                                        magicCookieSize: 0,
                                                        magicCookie: nil,
                                                        extensions: nil,
                                                        formatDescriptionOut: &audioFormatDescription)
            assert(status == noErr)
            
            var blockBuffer: CMBlockBuffer?
            status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: frame.buffer,
                blockLength: audioDataSize,
                blockAllocator: kCFAllocatorNull,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: audioDataSize,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            assert(status == kCMBlockBufferNoErr)
            
            guard let blockBuffer = blockBuffer else {
                return false
            }

            if status == kCMBlockBufferNoErr {
                var sampleBuffer: CMSampleBuffer?
                
                status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                    allocator: kCFAllocatorDefault,
                    dataBuffer: blockBuffer,      // dataBuffer
                    formatDescription: audioFormatDescription!,
                    sampleCount: audioDataSize,    // numSamples
                    presentationTimeStamp: CMTimeMakeWithSeconds(Double(frame.renderTimeMs) / 1000, preferredTimescale: Int32(DefaultAudioSampleRate)),    // sbufPTS
                    packetDescriptions: nil,        // packetDescriptions
                    sampleBufferOut: &sampleBuffer
                )
                assert(status == noErr)

                guard let sampleBuffer = sampleBuffer else {
                    log.error("sampleBuffer is nil")
                    return false
                }
                
                _ = appleAudioFileRecorder?.recordAudioSample(sampleBuffer: sampleBuffer)
            } else {
                log.error("Error in CMBlockBufferCreateWithMemoryBlock")
            }
        }
        return true
    }
    
    func getObservedAudioFramePosition() -> AgoraAudioFramePosition {
        return .record
    }
    
    func onRecord(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
    
    func onPlaybackAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
    
    func onMixedAudioFrame(_ frame: AgoraAudioFrame, channelId: String) -> Bool {
        return true
    }
    
    func onPlaybackAudioFrame(beforeMixing frame: AgoraAudioFrame, channelId: String, uid: UInt) -> Bool {
        return true
    }
}
