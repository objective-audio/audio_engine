//
//  yas_audio_device_tests.m
//

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <audio/yas_audio_device.h>
#import "yas_audio_test_utils.h"

using namespace yas;

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
    XCTAssertEqual(to_string(audio::device::method::device_did_change), "device_did_change");
}

- (void)test_system_method_string {
    XCTAssertEqual(to_string(audio::device::system_method::hardware_did_change), "hardware_did_change");
    XCTAssertEqual(to_string(audio::device::system_method::configuration_change), "configuration_change");
}

- (void)test_method_ostream {
    auto const values = {audio::device::method::device_did_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_system_method_ostream {
    auto const values = {audio::device::system_method::hardware_did_change,
                         audio::device::system_method::configuration_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end

#endif
