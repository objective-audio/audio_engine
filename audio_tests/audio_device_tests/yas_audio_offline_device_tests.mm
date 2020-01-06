//
//  yas_audio_offline_device_tests.mm
//

#import <audio/yas_audio_offline_device.h>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_offline_device_tests : XCTestCase

@end

@implementation yas_audio_offline_device_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_format {
    auto format = audio::format({.sample_rate = 44100, .channel_count = 2});

    auto const device = audio::offline_device::make_shared(
        format, [](audio::offline_render_args) { return audio::continuation::abort; }, [](bool const) {});

    XCTAssertEqual(device->output_format(), format);
    XCTAssertFalse(device->input_format().has_value());
}

- (void)test_completion_handler {
    auto format = audio::format({.sample_rate = 44100, .channel_count = 2});

    auto const device = audio::offline_device::make_shared(
        format, [](audio::offline_render_args) { return audio::continuation::abort; }, [](bool const) {});

    XCTAssertTrue(device->completion_handler().has_value());

    device->completion_handler().value()(false);

    XCTAssertFalse(device->completion_handler().has_value());
}

@end
