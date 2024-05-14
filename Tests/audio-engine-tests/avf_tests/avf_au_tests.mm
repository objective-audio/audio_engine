//
//  avf_au_tests.mm
//

#include <cpp-utils/fast_each.h>
#include <future>
#import "../test_utils.h"

using namespace yas;
using namespace yas::audio;

@interface avf_au_tests : XCTestCase

@end

@implementation avf_au_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_load {
    auto const au = avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    [self _load_au:au];

    auto const acd = au->componentDescription();
    XCTAssertEqual(acd.componentType, kAudioUnitType_FormatConverter);
    XCTAssertEqual(acd.componentSubType, kAudioUnitSubType_AUConverter);
}

- (void)test_initialize {
    auto const au = avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    [self _load_au:au];

    XCTAssertFalse(au->is_initialized());

    au->initialize();

    XCTAssertTrue(au->is_initialized());

    au->uninitialize();

    XCTAssertFalse(au->is_initialized());
}

- (void)test_set_parameter_value {
    auto const delay_au = avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    [self _load_au:delay_au];

    XCTAssertNotEqual(delay_au->global_parameter_value(kDelayParam_DelayTime), 100.0f);

    delay_au->set_global_parameter_value(kDelayParam_DelayTime, 100.0f);

    XCTAssertEqual(delay_au->global_parameter_value(kDelayParam_DelayTime), 100.0f);
}

- (void)test_parameters {
    auto const delay_au = avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    [self _load_au:delay_au];

    auto const input_params = delay_au->input_parameters();
    XCTAssertEqual(input_params.size(), 0);

    auto const output_params = delay_au->output_parameters();
    XCTAssertEqual(output_params.size(), 0);

    auto const global_params = delay_au->global_parameters();
    XCTAssertNotEqual(global_params.size(), 0);
}

- (void)test_format {
    auto const au = avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    [self _load_au:au];

    audio::format const output_format{
        {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = pcm_format::float32, .interleaved = false}};
    audio::format const input_format{
        {.sample_rate = 44100.0, .channel_count = 1, .pcm_format = pcm_format::int16, .interleaved = true}};

    au->set_output_format(output_format, 0);
    au->set_input_format(input_format, 0);

    XCTAssertTrue(au->output_format(0) == output_format);
    XCTAssertTrue(au->input_format(0) == input_format);
}

- (void)test_render {
    auto const au = avf_au::make_shared(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    [self _load_au:au];

    audio::format const format{
        {.sample_rate = 48000.0, .channel_count = 1, .pcm_format = pcm_format::int16, .interleaved = false}};

    au->set_output_format(format, 0);
    au->set_input_format(format, 0);

    audio::pcm_buffer buffer(format, 4);

    au->initialize();

    auto promise = std::make_shared<std::promise<void>>();
    auto future = promise->get_future();

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), [promise, au, &buffer] {
        audio::time time{1000};

        au->render({.buffer = &buffer, .bus_idx = 0, .time = time}, [](avf_au::render_args args) {
            int16_t *data = args.buffer->template data_ptr_at_index<int16_t>(0);

            auto each = make_fast_each(args.buffer->frame_length());
            while (yas_each_next(each)) {
                auto const &idx = yas_each_index(each);
                data[idx] = idx + 10;
            }
        });

        promise->set_value();
    });

    future.get();

    au->uninitialize();

    int16_t const *data = buffer.data_ptr_at_index<int16_t>(0);
    XCTAssertEqual(data[0], 10);
    XCTAssertEqual(data[1], 11);
    XCTAssertEqual(data[2], 12);
    XCTAssertEqual(data[3], 13);
}

- (void)test_reset_parameter {
    auto const delay_au = avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    [self _load_au:delay_au];

    auto const default_value = delay_au->global_parameter_value(kDelayParam_DelayTime);

    delay_au->set_global_parameter_value(kDelayParam_DelayTime, 100.0f);

    XCTAssertNotEqual(default_value, delay_au->global_parameter_value(kDelayParam_DelayTime));

    delay_au->reset();

    XCTAssertEqual(default_value, delay_au->global_parameter_value(kDelayParam_DelayTime));
}

- (void)test_load_state_to_string {
    XCTAssertEqual(to_string(avf_au::load_state::unload), "unload");
    XCTAssertEqual(to_string(avf_au::load_state::loaded), "loaded");
    XCTAssertEqual(to_string(avf_au::load_state::failed), "failed");
}

- (void)test_state {
    auto const au = avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    auto exp = [self expectationWithDescription:@"load"];

    auto canceller = au->observe_load_state([exp](auto const &state) {
                           if (state == avf_au::load_state::loaded) {
                               [exp fulfill];
                           }
                       }).sync();

    [self waitForExpectations:@[exp] timeout:1.0];

    XCTAssertEqual(au->state(), avf_au::load_state::loaded);

    canceller->cancel();
}

#pragma mark - private

- (void)_load_au:(audio::avf_au_ptr const &)au {
    auto exp = [self expectationWithDescription:@"load"];

    auto canceller = au->observe_load_state([exp](auto const &state) {
                           if (state == avf_au::load_state::loaded) {
                               [exp fulfill];
                           }
                       }).sync();

    [self waitForExpectations:@[exp] timeout:1.0];

    canceller->cancel();
}

@end
