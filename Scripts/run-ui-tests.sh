#!/bin/bash
SIM_NAME="UI Test (Korean)"
SCHEME="Example"
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
PROJECT_PATH="${SCRIPT_PATH}/../Example/Example.xcodeproj"
DESTINATION="platform=iOS Simulator,name=${SIM_NAME}"
xcrun simctl create "${SIM_NAME}" "iPhone 8"
xcrun simctl bootstatus "${SIM_NAME}" -b
xcodebuild build-for-testing -project $PROJECT_PATH -scheme $SCHEME -sdk iphonesimulator -destination "${DESTINATION}"
xcrun simctl spawn "${SIM_NAME}" defaults write .GlobalPreferences AppleKeyboards -array ko_KR@sw=Korean;hw=Automatic
xcodebuild test-without-building -project $PROJECT_PATH -scheme $SCHEME -sdk iphonesimulator -destination "${DESTINATION}"
xcrun simctl delete "${SIM_NAME}"
