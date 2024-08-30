# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'VideoPlayer' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  pod 'GoogleWebRTC'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # Ensure the project builds for all architectures, not just the active one
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
    end
  end

  installer.pods_project.build_configurations.each do |config|
    # Exclude arm64 architecture for iPhone simulators to avoid issues on Apple Silicon Macs
    config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
  end

  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        # Ensure the deployment target is set correctly for all dependencies
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end
