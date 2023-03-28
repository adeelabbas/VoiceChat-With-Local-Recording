
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
                self.startAppleLocalRecording(recordedFilePath: getAudioFilePath(audioFileExtension: "m4a" ))
                
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
    
    // -- Audio Muting
    var audioMuted = true // Initial toggle will make it false
    func ToggleAudioMuted() {
        self.audioMuted = !self.audioMuted
        agoraKit.muteLocalAudioStream(self.audioMuted)
        agoraKit.muteRecordingSignal(self.audioMuted)
        
        if self.audioMuted {
            audioMuteButton.title = "unmute"
            audioMuteButton.backgroundColor = .lightGray
        } else {
            audioMuteButton.title = "mute"
            audioMuteButton.backgroundColor = .white
        }
    }
    @IBOutlet weak var audioMuteButton: UIButton!
    @IBAction func audioMuteButtonPressed(_ sender: Any) {
        ToggleAudioMuted()
    }
    // -- Audio Muting

    var agoraKit: AgoraRtcEngineKit!
    @IBOutlet weak var container: AGEVideoContainer!
    @IBOutlet weak var recordingVolumeSlider: UISlider!
    @IBOutlet weak var playbackVolumeSlider: UISlider!
    @IBOutlet weak var inEarMonitoringSwitch: UISwitch!
    @IBOutlet weak var inEarMonitoringVolumeSlider: UISlider!
    @IBOutlet weak var scenarioBtn: UIButton! // Delete
        
    var audioViews: [UInt:VideoView] = [:]
    
    // indicate if current instance has joined channel
    var isJoined: Bool = false

    private var audioDevice : AudioDevice?

    override func viewDidLoad(){
        super.viewDidLoad()
        
        let audioSession = AVCaptureSession()
        let audioDevice = AudioDevice(captureSession: audioSession, audioSampleBufferDelegate: self)
        // Configure audio session
        
        // NOTE: If we uncomment following line, there is a lot of echo because the audio session does not have echo cancellation
//        audioSession.usesApplicationAudioSession = false
        
        audioSession.beginConfiguration()
        guard audioDevice.configureAudio() else {
            log.error("audioDevice.configureAudio failed")
            return
        }
        audioSession.commitConfiguration()
        
        self.audioDevice = audioDevice
        
        DispatchQueue(label: "Audio Session Queue").async {
            audioSession.startRunning()
        }
        
        guard let channelName = configs["channelName"] as? String
            else { return }

        // set up agora instance when view loaded
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        config.areaCode = .global
        config.channelProfile = .communication
        // set audio scenario
        config.audioScenario = .default
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit.setLogFile(LogUtils.sdkLogPath())
        
        // make myself a broadcaster
        agoraKit.setClientRole(.broadcaster)
        
        // disable video module
        agoraKit.disableVideo()
        
        agoraKit.enableAudio()
        
        // set audio profile
        agoraKit.setAudioProfile(.default)
        
        // Set audio route to speaker
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        
        // enable volume indicator
        agoraKit.enableAudioVolumeIndication(200, smooth: 3, reportVad: true)
        
        recordingVolumeSlider.maximumValue = 400
        recordingVolumeSlider.minimumValue = 0
        recordingVolumeSlider.integerValue = 100
        
        playbackVolumeSlider.maximumValue = 400
        playbackVolumeSlider.minimumValue = 0
        playbackVolumeSlider.integerValue = 100
        
        inEarMonitoringVolumeSlider.maximumValue = 100
        inEarMonitoringVolumeSlider.minimumValue = 0
        inEarMonitoringVolumeSlider.integerValue = 100
        
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
        
        let result = agoraKit.joinChannel(byToken: KeyCenter.Token, channelId: channelName, uid: 0, mediaOptions: option)
        if result != 0 {
            // Usually happens with invalid parameters
            // Error code description can be found at:
            // en: https://docs.agora.io/en/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
            // cn: https://docs.agora.io/cn/Voice/API%20Reference/oc/Constants/AgoraErrorCode.html
            self.showAlert(title: "Error", message: "joinChannel call failed: \(result), please check your params")
        }
        
        ToggleAudioMuted()
        ToggleAudioIsRecorded(firsttime: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // 关闭耳返
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
    @IBAction func setAudioScenario(_ sender: Any) {
        let alert = UIAlertController(title: "Set Audio Scenario".localized, message: nil, preferredStyle: UIDevice.current.userInterfaceIdiom == .pad ? UIAlertController.Style.alert : UIAlertController.Style.actionSheet)
        for scenario in AgoraAudioScenario.allValues(){
            alert.addAction(getAudioScenarioAction(scenario))
        }
        alert.addCancelAction()
        present(alert, animated: true, completion: nil)
    }
    
    func getAudioScenarioAction(_ scenario:AgoraAudioScenario) -> UIAlertAction{
        return UIAlertAction(title: "\(scenario.description())", style: .default, handler: {[unowned self] action in
            self.agoraKit.setAudioScenario(scenario)
            self.scenarioBtn.setTitle("\(scenario.description())", for: .normal)
        })
    }
    
    @IBAction func onChangeRecordingVolume(_ sender:UISlider){
        let value:Int = Int(sender.value)
        print("adjustRecordingSignalVolume \(value)")
        agoraKit.adjustRecordingSignalVolume(value)
    }
    
    @IBAction func onChangePlaybackVolume(_ sender:UISlider){
        let value:Int = Int(sender.value)
        print("adjustPlaybackSignalVolume \(value)")
        agoraKit.adjustPlaybackSignalVolume(value)
    }
    
    @IBAction func toggleInEarMonitoring(_ sender:UISwitch){
        inEarMonitoringVolumeSlider.isEnabled = sender.isOn
        agoraKit.enable(inEarMonitoring: sender.isOn)
    }
    
    @IBAction func onChangeInEarMonitoringVolume(_ sender:UISlider){
        let value:Int = Int(sender.value)
        print("setInEarMonitoringVolume \(value)")
        agoraKit.setInEarMonitoringVolume(value)
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

extension JoinChannelAudioMain : AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if audioIsRecorded {
            if let appleAudioFileRecorder = self.appleAudioFileRecorder {
                guard appleAudioFileRecorder.recordAudioSample(sampleBuffer: sampleBuffer) else {
                    log.error("Could not record audio sample")
                    return
                }
            }
        }
    }
}
