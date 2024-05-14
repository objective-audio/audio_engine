//
//  device_stream_tests.m
//

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "../test_utils.h"

using namespace yas;

@interface device_stream_tests : XCTestCase

@end

@implementation device_stream_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::mac_device::stream::method::did_change), "did_change");
}

- (void)test_method_ostream {
    auto const values = {audio::mac_device::stream::method::did_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end

#endif
