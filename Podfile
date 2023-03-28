target 'VoiceChat-With-Local-Recording' do
  use_frameworks!
  
  pod 'AGEVideoLayout', '~> 1.0.2'
  pod 'AgoraAudio_iOS', '4.1.1'
  pod 'Loggerithm', '~> 1.5'
end

post_install do |installer|
    installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
               end
          end
   end
end