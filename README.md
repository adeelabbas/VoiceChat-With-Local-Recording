## Local audio recording bug on iPhone 14 for voice-conferencing applications

### Overview
We are experiencing a local audio recording issue on iPhone 14 when for voice conferencing application. There is no problem on iPhone 13 and older devices. Also interesting to note is that when an iPhone 14 device is the only device in the call, the problem does not happen. We think the problem might be related to hardware echo cancellation on the iPhone 14 - when it's speaker is open, the audio captured by device has audible artifacts.

### How to Reproduce Problem

- Please email [me](adeel@roll.ai) for `AppId` and `Certificate` - enter them in [Source/Common/KeyCenter.swift](https://github.com/adeelabbas/VoiceChat-With-Local-Recording/blob/main/Source/Common/KeyCenter.swift). 
- Run app on two devices - one on iPhone-14 and the other on iPhone-13 (or older).
- Tap `Join` on iPhone-13 (a default channel is automatically filled up in the text box). Then tap `start recording`
- Take iPhone-14 to another room - to minimize echo since both devices will be in the same call - tap `Join`, then `start recording`
- Speak some words in the iPhone-14 - record for 30 seconds. Then, tap `stop recording` on both devices
- Connect iPhone 14 to Mac computer and open Finder app. Click on the icon showing iPhone-14 name on left panel and navigate to `Files` tab. Then click on `>` symbol next to  `VoiceChat-With-Local-Recording`. 
![](Media/Finder.png "Downloading from Finder app")
- There will be an audio file with `m4a` extension - drag and drop it to your local directory and play. Audio will have artifacts. [Here](https://www.dropbox.com/s/lpxw2fh0o7ojq60/Sample-audio.m4a?dl=0) is a sample audio with the artifacts (this file is also available in this repo at [Media/Sample-audio.m4a](https://github.com/adeelabbas/VoiceChat-With-Local-Recording/blob/main/Media/sample-audio.m4a)).


### Technical Details
- In order to implement voice conferencing, we are using Agora Voice SDK.
- We are recording local audio using `AVCaptureSession` and `AVAssetWriter`

Spectrogram of audio looks like this:
![](Media/Spectrogram.png "Spectrogram of problematic audio")