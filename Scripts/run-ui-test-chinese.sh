#!/bin/bash
SIMULATOR_NAME="UI Test (Chinese)"
SCHEME="Host"
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
PROJECT_PATH="${SCRIPT_PATH}/../UITests/UITests.xcodeproj"
# Disable "Use the Same Keyboard Language as macOS" in Simulator.app.
defaults write com.apple.iphonesimulator EnableKeyboardSync -bool NO
# Create the simulator we will use for the tests.
xcrun simctl create "${SIMULATOR_NAME}" "iPhone 13" "iOS15.5" 2> /dev/null
# Find the UDID of the newly created simulator.
SIMULATOR_UDID=`xcrun simctl list --json devices | jq -r ".devices | flatten | .[] | select(.name == \"${SIMULATOR_NAME}\").udid"`
# Edit the simulator's .GlobalPreferences.plist to use the Chinese language.
find ~/Library/Developer/CoreSimulator/Devices/${SIMULATOR_UDID} -type d -maxdepth 0\
  -exec /usr/libexec/PlistBuddy\
  -c "Add :AppleKeyboardsExpanded integer 1"\
  -c "Delete :AppleLanguages"\
  -c "Add :AppleLanguages array"\
  -c "Add :AppleLanguages:0 string en-US"\
  -c "Delete :AppleKeyboards"\
  -c "Add :AppleKeyboards array"\
  -c "Add :AppleKeyboards:0 string zh_Hant-Sucheng@sw=Sucheng;hw=Automatic"\
  {}/data/Library/Preferences/.GlobalPreferences.plist \;
# Disable "Connect Hardware Keyboard" in the simulator.
/usr/libexec/PlistBuddy\
  -c "Add :DevicePreferences dict"\
  -c "Add :DevicePreferences:${SIMULATOR_UDID} dict"\
  -c "Add :DevicePreferences:${SIMULATOR_UDID}:ConnectHardwareKeyboard bool false"\
  ~/Library/Preferences/com.apple.iphonesimulator.plist
# Build the project and run the tests.
xcodebuild build-for-testing\
  -project $PROJECT_PATH\
  -scheme $SCHEME\
  -sdk iphonesimulator\
  -destination "platform=iOS Simulator,id=${SIMULATOR_UDID}"
xcodebuild test-without-building\
  -only-testing:HostUITests/ChineseInputTests\
  -project $PROJECT_PATH\
  -scheme $SCHEME\
  -sdk iphonesimulator\
  -destination "platform=iOS Simulator,id=${SIMULATOR_UDID}"
# Remove preferences specific to the simulator.
/usr/libexec/PlistBuddy\
  -c "Delete :DevicePreferences:${SIMULATOR_UDID}"\
  ~/Library/Preferences/com.apple.iphonesimulator.plist
# Remove the simulator we created earlier.
xcrun simctl delete $SIMULATOR_UDID