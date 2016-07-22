//
//  yas_audio_device_tests.m
//

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "yas_audio_device.h"
#import "yas_audio_test_utils.h"

@interface yas_audio_device_tests : XCTestCase

@end

@implementation yas_audio_device_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::device::method::hardware_did_change), "hardware_did_change");
    XCTAssertEqual(to_string(audio::device::method::device_did_change), "device_did_change");
    XCTAssertEqual(to_string(audio::device::method::configuration_change), "configuration_change");
}

- (void)test_method_ostream {
    auto const values = {audio::device::method::hardware_did_change, audio::device::method::device_did_change,
                         audio::device::method::configuration_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end

#endif
