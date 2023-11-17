#source 'https://cdn.cocoapods.org/'
source 'https://github.com/CocoaPods/Specs.git'
#source 'http://10.1.1.252:3000/Sending/ParticleAuthServiceSpecs.git'
source 'http://10.1.1.252:3000/Sending/ParticleAuthServiceSpecs.git'


# Uncomment this line to define a global platform for your project
platform :ios, '14.0'

# By default, ignore all warnings from any pod
inhibit_all_warnings!

# Use frameworks to allow usage of pods written in Swift
use_frameworks!

# Different flavours of pods to SDNSDK. Can be one of:
# - a String indicating an official SDNSDK released version number
# - `:local` (to use Development Pods)
# - `{ :branch => 'sdk branch name'}` to depend on specific branch of SDNSDK repo
# - `{ :specHash => {sdk spec hash}` to depend on specific pod options (:git => …, :podspec => …) for SDNSDK repo. Used by Fastfile during CI
#
# Warning: our internal tooling depends on the name of this variable name, so be sure not to change it
#$sdnSDKVersion = '= 0.26.12'
 $sdnSDKVersion = :local
# $sdnSDKVersion = { :branch => 'develop'}
# $sdnSDKVersion = { :specHash => { git: 'https://git.io/fork123', branch: 'fix' } }

########################################

case $sdnSDKVersion
when :local
$sdnSDKVersionSpec = { :path => '../sendingnetwork-ios/SDNSDK.podspec' }
when Hash
spec_mode, sdk_spec = $sdnSDKVersion.first # extract first and only key/value pair; key is spec_mode, value is sdk_spec


  case spec_mode
  when :branch
  # :branch => sdk branch name
  sdk_spec = { :git => 'https://github.com/sdn-org/sdn-ios-sdk.git', :branch => sdk_spec.to_s } unless sdk_spec.is_a?(Hash)
  when :specHash
  # :specHash => {sdk spec Hash}
  sdk_spec = sdk_spec
  end

$sdnSDKVersionSpec = sdk_spec
when String # specific SDNSDK released version
$sdnSDKVersionSpec = $sdnSDKVersion
end

# Method to import the SDNSDK
def import_SDNSDK
  pod 'SDNSDK', $sdnSDKVersionSpec, :inhibit_warnings => false
  pod 'SDNSDK/JingleCallStack', $sdnSDKVersionSpec, :inhibit_warnings => false
end


#def import_SDNSDK
#  pod 'SDNSDK',:path =>'../sdn-ios-sdk/'
#  pod 'SDNSDK/JingleCallStack',:path =>'../sdn-ios-sdk/'
#end

########################################

def import_SDNKit_pods
  pod 'libPhoneNumber-iOS', '~> 0.9.13'  
  pod 'Down', '~> 0.11.0'
end

def import_SwiftUI_pods
    pod 'Introspect', '~> 0.1'
    pod 'DSBottomSheet', '~> 0.3'
    pod 'ZXingObjC', '~> 3.6.5'
  #  pod 'ZXingObjC',:path =>'../zxingifysdn'
end

abstract_target 'SendingnNetworkPods' do

  pod 'GBDeviceInfo', '~> 7.1.0'
  pod 'Reusable', '~> 4.1'
  pod 'KeychainAccess', '~> 4.2.2'
  pod 'WeakDictionary', '~> 2.0'

  # PostHog for analytics
  pod 'PostHog', '~> 2.0.0'
  pod 'Sentry', '~> 7.15.0'
  pod 'web3swift'
  pod 'OLMKit'
  pod 'zxcvbn-ios'
#  pod 'ParticleAuthServiceWrap', '0.0.4'
#  pod 'ParticleAuthServiceWrap',:path =>'./ParticleAuthServiceWrap'

  # Tools
  pod 'SwiftGen'
  pod 'SwiftLint'
  pod 'SwiftFormat/CLI'

  target "SendingnNetwork" do
    import_SDNSDK
    import_SDNKit_pods

    import_SwiftUI_pods

    pod 'UICollectionViewRightAlignedLayout', '~> 0.0.3'
    pod 'UICollectionViewLeftAlignedLayout', '~> 1.0.2'
    pod 'KTCenterFlowLayout', '~> 1.3.1'
    pod 'FlowCommoniOS', '~> 1.12.0'
    pod 'ReadMoreTextView', '~> 3.0.1'
    pod 'SwiftBase32', '~> 0.9.0'
    pod 'SwiftJWT', '~> 3.6.200'
    pod 'SideMenu', '~> 6.5'
    pod 'DSWaveformImage', '~> 6.1.1'
    
    pod 'FLEX', '~> 4.5.0', :configurations => ['Debug'], :inhibit_warnings => true

    target 'SendingnNetworkTests' do
      inherit! :search_paths
    end
  end

  target "SendingnNetworkSwiftUI" do
    import_SwiftUI_pods
  end

  target "SendingnNetworkSwiftUITests" do
    import_SwiftUI_pods
  end

 # target "SendingnNetworkNSE" do
   # import_SDNSDK
   # import_SDNKit_pods
 # end



  # Disabled due to crypto corruption issues.
  # https://github.com/Sending-Network/sendingnetwork-ios/issues/7618
  # target "SendingnNetworkShareExtension" do
  #   import_SDNSDK
  #   import_SDNKit_pods
  # end
  #
  # target "SiriIntents" do
  #   import_SDNSDK
  #   import_SDNKit_pods
  # end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|

    target.build_configurations.each do |config|
      # Disable bitcode for each pod framework
      # Because the WebRTC pod (included by the JingleCallStack pod) does not support it.
      # Plus the app does not enable it
      config.build_settings['ENABLE_BITCODE'] = 'NO'

      # Force ReadMoreTextView to use Swift 5.2 version (as there is no code changes to perform)
      if target.name.include? 'ReadMoreTextView'
        config.build_settings['SWIFT_VERSION'] = '5.2'
      end

      # Stop Xcode 12 complaining about old IPHONEOS_DEPLOYMENT_TARGET from pods
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'

      # Disable nullability checks
      config.build_settings['WARNING_CFLAGS'] ||= ['$(inherited)','-Wno-nullability-completeness']
      config.build_settings['OTHER_SWIFT_FLAGS'] ||= ['$(inherited)', '-Xcc', '-Wno-nullability-completeness']
    end

    # Fix Xcode 14 resource bundle signing issues
    # https://github.com/CocoaPods/CocoaPods/issues/11402#issuecomment-1259231655
    if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
      target.build_configurations.each do |config|
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end

  end
end
