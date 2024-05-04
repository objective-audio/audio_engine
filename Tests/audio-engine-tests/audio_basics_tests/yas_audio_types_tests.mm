//
//  yas_audio_types_tests.mm
//

#import "../yas_audio_test_utils.h"

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

- (void)test_pcm_format_to_string {
    XCTAssertTrue(to_string(audio::pcm_format::float32) == "Float32");
    XCTAssertTrue(to_string(audio::pcm_format::float64) == "Float64");
    XCTAssertTrue(to_string(audio::pcm_format::int16) == "Int16");
    XCTAssertTrue(to_string(audio::pcm_format::fixed824) == "Fixed8.24");
    XCTAssertTrue(to_string(audio::pcm_format::other) == "Other");
}

- (void)test_pcm_format_to_sample_type {
    XCTAssertTrue(to_sample_type(audio::pcm_format::float32) == typeid(float));
    XCTAssertTrue(to_sample_type(audio::pcm_format::float64) == typeid(double));
    XCTAssertTrue(to_sample_type(audio::pcm_format::int16) == typeid(int16_t));
    XCTAssertTrue(to_sample_type(audio::pcm_format::fixed824) == typeid(int32_t));
    XCTAssertTrue(to_sample_type(audio::pcm_format::other) == typeid(std::nullptr_t));
}

- (void)test_pcm_format_to_bit_depth {
    XCTAssertTrue(to_bit_depth(audio::pcm_format::float32) == 32);
    XCTAssertTrue(to_bit_depth(audio::pcm_format::float64) == 64);
    XCTAssertTrue(to_bit_depth(audio::pcm_format::int16) == 16);
    XCTAssertTrue(to_bit_depth(audio::pcm_format::fixed824) == 32);
    XCTAssertTrue(to_bit_depth(audio::pcm_format::other) == 0);
}

- (void)test_pcm_format_ostream {
    auto const errors = {audio::pcm_format::float32, audio::pcm_format::float64, audio::pcm_format::int16,
                         audio::pcm_format::fixed824, audio::pcm_format::other};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
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
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Global), "global");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Input), "input");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Output), "output");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Group), "group");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Part), "part");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Note), "note");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_Layer), "layer");
    XCTAssertEqual(to_string((AudioUnitScope)kAudioUnitScope_LayerItem), "layer_item");
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

    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidProperty), "InvalidProperty");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidParameter), "InvalidParameter");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidElement), "InvalidElement");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_NoConnection), "NoConnection");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_FailedInitialization), "FailedInitialization");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_TooManyFramesToProcess), "TooManyFramesToProcess");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidFile), "InvalidFile");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_FormatNotSupported), "FormatNotSupported");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_Uninitialized), "Uninitialized");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidScope), "InvalidScope");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_PropertyNotWritable), "PropertyNotWritable");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_CannotDoInCurrentContext), "CannotDoInCurrentContext");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidPropertyValue), "InvalidPropertyValue");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_PropertyNotInUse), "PropertyNotInUse");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_Initialized), "Initialized");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_InvalidOfflineRender), "InvalidOfflineRender");
    XCTAssertEqual(to_string((OSStatus)kAudioUnitErr_Unauthorized), "Unauthorized");

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareNotRunningError), "HardwareNotRunning");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareUnspecifiedError), "HardwareUnspecifiedError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareUnknownPropertyError), "HardwareUnknownPropertyError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareBadPropertySizeError), "HardwareBadPropertySizeError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareIllegalOperationError), "HardwareIllegalOperationError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareBadObjectError), "HardwareBadObjectError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareBadDeviceError), "HardwareBadDeviceError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareBadStreamError), "HardwareBadStreamError");
    XCTAssertEqual(to_string((OSStatus)kAudioHardwareUnsupportedOperationError), "HardwareUnsupportedOperationError");
    XCTAssertEqual(to_string((OSStatus)kAudioDeviceUnsupportedFormatError), "DeviceUnsupportedFormatError");
    XCTAssertEqual(to_string((OSStatus)kAudioDevicePermissionsError), "DevicePermissionsError");
#endif

    err = 1;
    XCTAssertEqual(to_string(err), "Unknown");
}

@end
