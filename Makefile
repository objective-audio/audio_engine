WORKSPACE = audio.xcworkspace
SCHEME = audio_ios_tests
CONFIGURATION = Release
SDK = iphonesimulator

test:
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration $(CONFIGURATION) OBJROOT=build -sdk $(SDK) clean test

setup-coverage:
	sudo easy_install cpp-coveralls

send-coverage:
	coveralls --exclude-pattern ".*Tests" --exclude-pattern ".*\.h" -e submodules -e
