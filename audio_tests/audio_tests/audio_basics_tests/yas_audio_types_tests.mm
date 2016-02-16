//
//  yas_audio_types_tests.mm
//

#import "yas_audio_test_utils.h"

@interface yas_audio_types_tests : XCTestCase

@end

@implementation yas_audio_types_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_to_uint32_direction {
    XCTAssertEqual(yas::to_uint32(yas::audio::direction::output), 0);
    XCTAssertEqual(yas::to_uint32(yas::audio::direction::input), 1);
}

- (void)test_to_string_direction {
    XCTAssertEqual(yas::to_string(yas::audio::direction::output), "output");
    XCTAssertEqual(yas::to_string(yas::audio::direction::input), "input");
}

- (void)test_to_string_scope {
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Global), "global");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Input), "input");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Output), "output");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Group), "group");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Part), "part");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Note), "note");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_Layer), "layer");
    XCTAssertEqual(yas::to_string(kAudioUnitScope_LayerItem), "layer_item");
    XCTAssertEqual(yas::to_string((AudioUnitScope)-1), "unknown");
}

- (void)test_to_string_render_type {
    XCTAssertEqual(yas::to_string(yas::audio::render_type::normal), "normal");
    XCTAssertEqual(yas::to_string(yas::audio::render_type::notify), "notify");
    XCTAssertEqual(yas::to_string(yas::audio::render_type::input), "input");
    XCTAssertEqual(yas::to_string(yas::audio::render_type::unknown), "unknown");
}

- (void)test_to_string_audio_error {
    OSStatus err = noErr;
    XCTAssertEqual(yas::to_string(err), "noErr");

    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidProperty), "InvalidProperty");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidParameter), "InvalidParameter");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidElement), "InvalidElement");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_NoConnection), "NoConnection");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_FailedInitialization), "FailedInitialization");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_TooManyFramesToProcess), "TooManyFramesToProcess");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidFile), "InvalidFile");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_FormatNotSupported), "FormatNotSupported");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_Uninitialized), "Uninitialized");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidScope), "InvalidScope");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_PropertyNotWritable), "PropertyNotWritable");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_CannotDoInCurrentContext), "CannotDoInCurrentContext");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidPropertyValue), "InvalidPropertyValue");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_PropertyNotInUse), "PropertyNotInUse");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_Initialized), "Initialized");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_InvalidOfflineRender), "InvalidOfflineRender");
    XCTAssertEqual(yas::to_string(kAudioUnitErr_Unauthorized), "Unauthorized");

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    XCTAssertEqual(yas::to_string(kAudioHardwareNotRunningError), "HardwareNotRunning");
    XCTAssertEqual(yas::to_string(kAudioHardwareUnspecifiedError), "HardwareUnspecifiedError");
    XCTAssertEqual(yas::to_string(kAudioHardwareUnknownPropertyError), "HardwareUnknownPropertyError");
    XCTAssertEqual(yas::to_string(kAudioHardwareBadPropertySizeError), "HardwareBadPropertySizeError");
    XCTAssertEqual(yas::to_string(kAudioHardwareIllegalOperationError), "HardwareIllegalOperationError");
    XCTAssertEqual(yas::to_string(kAudioHardwareBadObjectError), "HardwareBadObjectError");
    XCTAssertEqual(yas::to_string(kAudioHardwareBadDeviceError), "HardwareBadDeviceError");
    XCTAssertEqual(yas::to_string(kAudioHardwareBadStreamError), "HardwareBadStreamError");
    XCTAssertEqual(yas::to_string(kAudioHardwareUnsupportedOperationError), "HardwareUnsupportedOperationError");
    XCTAssertEqual(yas::to_string(kAudioDeviceUnsupportedFormatError), "DeviceUnsupportedFormatError");
    XCTAssertEqual(yas::to_string(kAudioDevicePermissionsError), "DevicePermissionsError");
#endif

    err = 1;
    XCTAssertEqual(yas::to_string(err), "Unknown");
}

@end
