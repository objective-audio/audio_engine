//
//  yas_audio_io_device_tests.m
//

#include <TargetConditionals.h>

#import "yas_audio_test_io_device.h"
#import "yas_audio_test_utils.h"

using namespace yas;
using namespace yas::test;

@interface yas_audio_device_tests : XCTestCase

@end

@implementation yas_audio_device_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_empty_channel_count {
    auto const device = test_io_device::make_shared();

    XCTAssertEqual(device->input_channel_count(), 0);
    XCTAssertEqual(device->output_channel_count(), 0);
}

- (void)test_channel_count {
    auto const device = test_io_device::make_shared();
    device->input_format_handler = []() { return audio::format{{.sample_rate = 44100.0, .channel_count = 1}}; };
    device->output_format_handler = []() { return audio::format{{.sample_rate = 44100.0, .channel_count = 2}}; };

    XCTAssertEqual(device->input_channel_count(), 1);
    XCTAssertEqual(device->output_channel_count(), 2);
}

@end
