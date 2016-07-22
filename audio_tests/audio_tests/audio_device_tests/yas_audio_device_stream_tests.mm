//
//  yas_audio_device_stream_tests.m
//

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "yas_audio_device_stream.h"
#import "yas_audio_test_utils.h"

@interface yas_audio_device_stream_tests : XCTestCase

@end

@implementation yas_audio_device_stream_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::device::stream::method::did_change), "did_change");
}

- (void)test_method_ostream {
    auto const values = {audio::device::stream::method::did_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end

#endif
