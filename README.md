# Audio Issue on iPhone 14 with Agora SDK

We are experiencing an audio issue on iPhone 14 when using Agora SDK with custom audio recording using `AVCaptureSession` and `AVAssetWriter`. There is no problem on iPhone 13 and older devices. Also interesting to note is that when an iPhone 14 device is the only device in the call, no error happens. The error happens when there is another device in the call sending audio to iPhone 14. We think that the problem happens when iPhone 14 speakerphone is open and at the same time as microphone from another `AVCaptureSession` is trying to capture samples. 

# How to run sample app

- Enter `AppId` and `Certificate` in `KeyCenter.swift`
- Run app on two devices - one iPhone 14 and one iPhone 13 or older
- Tap on Join a channel (Audio) on both devices
- In the edit box, write channel name to join on both devices
- Tap on `start recording` button - record for 10 seconds. Then, tap `stop recording`
- Connect iPhone 13 to Mac computer and open Finder app. Navigate to `Files` tab and click on `APIExample-Audio`. 
- There will be an m4a audio file written on iPhone 13, while no m4a audio file for iPhone 14.

