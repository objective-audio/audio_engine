//
//  yas_audio_types_tests.mm
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_types_tests : XCTestCase

@end

@implementation yas_audio_types_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_direction_to_uint32 {
    XCTAssertEqual(to_uint32(audio::direction::output), 0);
    XCTAssertEqual(to_uint32(audio::direction::input), 1);
}

- (void)test_direction_to_string {
    XCTAssertEqual(to_string(audio::direction::output), "output");
    XCTAssertEqual(to_string(audio::direction::input), "input");
}

- (void)test_direction_ostream {
    auto const values = {audio::direction::output, audio::direction::input};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_scope_to_string {
    XCTAssertEqual(to_string(kAudioUnitScope_Global), "global");
    XCTAssertEqual(to_string(kAudioUnitScope_Input), "input");
    XCTAssertEqual(to_string(kAudioUnitScope_Output), "output");
    XCTAssertEqual(to_string(kAudioUnitScope_Group), "group");
    XCTAssertEqual(to_string(kAudioUnitScope_Part), "part");
    XCTAssertEqual(to_string(kAudioUnitScope_Note), "note");
    XCTAssertEqual(to_string(kAudioUnitScope_Layer), "layer");
    XCTAssertEqual(to_string(kAudioUnitScope_LayerItem), "layer_item");
    XCTAssertEqual(to_string((AudioUnitScope)-1), "unknown");
}

- (void)test_render_type_to_string {
    XCTAssertEqual(to_string(audio::render_type::normal), "normal");
    XCTAssertEqual(to_string(audio::render_type::notify), "notify");
    XCTAssertEqual(to_string(audio::render_type::input), "input");
    XCTAssertEqual(to_string(audio::render_type::unknown), "unknown");
}

- (void)test_render_type_ostream {
    auto const values = {audio::render_type::normal, audio::render_type::notify, audio::render_type::input,
                         audio::render_type::unknown};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_audio_error_to_string {
    OSStatus err = noErr;
    XCTAssertEqual(to_string(err), "noErr");

    XCTAssertEqual(to_string(kAudioUnitErr_InvalidProperty), "InvalidProperty");
    XCTAssertEqual(to_string(kAudioUnitErr_InvalidParameter), "InvalidParameter");
    XCTAssertEqual(to_string(kAudioUnitErr_InvalidElement), "InvalidElement");
    XCTAssertEqual(to_string(kAudioUnitErr_NoConnection), "NoConnection");
    XCTAssertEqual(to_string(kAudioUnitErr_FailedInitialization), "FailedInitialization");
    XCTAssertEqual(to_string(kAudioUnitErr_TooManyFramesToProcess), "TooManyFramesToProcess");
    XCTAssertEqual(to_string(kAudioUnitErr_InvalidFile), "InvalidFile");
    XCTAssertEqual(to_string(kAudioUnitErr_FormatNotSupported), "FormatNotSupported");
    XCTAssertEqual(to_string(kAudioUnitErr_Uninitialized), "Uninitialized");
    XCTAssertEqual(to_string(kAudioUnitErr_InvalidScope), "InvalidScope");
    XCTAssertEqual(to_string(kAudioUnitErr_PropertyNotWritable), "PropertyNotWritable");
    XCTAssertEqual(to_string(kAudioUnitErr_CannotDoInCurrentContext), "CannotDoInCurrentContext");
    XCTAssertEqual(to_string(kAudioUnitErr_InvalidPropertyValue), "InvalidPropertyValue");
    XCTAssertEqual(to_string(kAudioUnitErr_PropertyNotInUse), "PropertyNotInUse");
    XCTAssertEqual(to_string(kAudioUnitErr_Initialized), "Initialized");
    XCTAssertEqual(to_string(kAudioUnitErr_InvalidOfflineRender), "InvalidOfflineRender");
    XCTAssertEqual(to_string(kAudioUnitErr_Unauthorized), "Unauthorized");

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    XCTAssertEqual(to_string(kAudioHardwareNotRunningError), "HardwareNotRunning");
    XCTAssertEqual(to_string(kAudioHardwareUnspecifiedError), "HardwareUnspecifiedError");
    XCTAssertEqual(to_string(kAudioHardwareUnknownPropertyError), "HardwareUnknownPropertyError");
    XCTAssertEqual(to_string(kAudioHardwareBadPropertySizeError), "HardwareBadPropertySizeError");
    XCTAssertEqual(to_string(kAudioHardwareIllegalOperationError), "HardwareIllegalOperationError");
    XCTAssertEqual(to_string(kAudioHardwareBadObjectError), "HardwareBadObjectError");
    XCTAssertEqual(to_string(kAudioHardwareBadDeviceError), "HardwareBadDeviceError");
    XCTAssertEqual(to_string(kAudioHardwareBadStreamError), "HardwareBadStreamError");
    XCTAssertEqual(to_string(kAudioHardwareUnsupportedOperationError), "HardwareUnsupportedOperationError");
    XCTAssertEqual(to_string(kAudioDeviceUnsupportedFormatError), "DeviceUnsupportedFormatError");
    XCTAssertEqual(to_string(kAudioDevicePermissionsError), "DevicePermissionsError");
#endif

    err = 1;
    XCTAssertEqual(to_string(err), "Unknown");
}

@end
