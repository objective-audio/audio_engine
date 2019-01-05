WORKSPACE = audio.xcworkspace
SCHEME = audio_ios_tests
CONFIGURATION = Release
SDK = iphonesimulator
DESTINATION = 'platform=iOS Simulator,name=iPhone 6,OS=12.1'

test_ios:
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION) OBJROOT=build -sdk $(SDK) -destination $(DESTINATION) clean test

test_osx:
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION) OBJROOT=build -sdk $(SDK) clean test

setup-coverage:
	sudo easy_install cpp-coveralls

send-coverage:
	coveralls --exclude-pattern ".*Tests" --exclude-pattern ".*\.h" -e submodules -e
