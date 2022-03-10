# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'
use_frameworks!

def fb_pods
  pod 'FBSDKShareKit'
  pod 'FBSDKLoginKit'
  pod 'Bolts'
end

target 'FBUtility' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # Pods for FBUtility
  fb_pods

  target 'FBUtilityAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'FBUtilityTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'FBUtilityApp' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # Pods for FBUtilityApp
  fb_pods
end

target 'FBUtilityLib' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # Pods for FBUtilityLib
  fb_pods
end
