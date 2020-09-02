#!/usr/bin/env bash

DO_NOT_SIGN='CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED=NO'

rm -rf build/
xcodebuild archive -scheme CSCapture -sdk iphoneos OBJROOT=build ${DO_NOT_SIGN}
xcodebuild archive -scheme CSCapture -sdk iphonesimulator OBJROOT=build ${DO_NOT_SIGN}

xcodebuild -create-xcframework -framework build/UninstalledProducts/iphoneos/CSCapture.framework -framework build/UninstalledProducts/iphonesimulator/CSCapture.framework -output build/CSCapture.xcframework
