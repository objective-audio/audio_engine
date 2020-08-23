//
//  yas_audio_graph_offline_io_tests.mm
//

#include <future>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_offline_io_tests : XCTestCase

@end

@implementation yas_audio_graph_offline_io_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_offline_render_with_graph {
    auto graph = audio::graph::make_shared();

    double const sample_rate = 44100.0;
    auto format = audio::format({.sample_rate = sample_rate, .channel_count = 2});

    auto sample_delay_au = audio::graph_avf_au::make_shared(kAudioUnitType_Effect, kAudioUnitSubType_SampleDelay);
    auto tap = audio::graph_tap::make_shared();

    auto promise = std::make_shared<std::promise<void>>();
    auto future = promise->get_future();

    auto observer = sample_delay_au->load_state_chain()
                        .perform([promise](auto const &state) {
                            if (state == audio::avf_au::load_state::loaded) {
                                promise->set_value();
                            }
                        })
                        .sync();

    future.get();

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    uint32_t const frames_per_render = 1024;
    uint32_t const length = 4192;
    uint32_t tap_render_frame = 0;

    auto tap_render_handler = [&self, &tapNodeExpectation, &tap_render_frame, &sample_rate, &frames_per_render,
                               &format](audio::graph_node::render_args args) {
        auto &buffer = args.output_buffer;
        auto const &when = args.when;

        XCTAssertEqual(when.sample_time(), tap_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer->frame_length(), frames_per_render);
        XCTAssertTrue(buffer->format() == format);

        for (uint32_t buf_idx = 0; buf_idx < buffer->format().buffer_count(); ++buf_idx) {
            float *ptr = buffer->data_ptr_at_index<float>(buf_idx);
            for (uint32_t frm_idx = 0; frm_idx < buffer->frame_length(); ++frm_idx) {
                ptr[frm_idx] = test::test_value(frm_idx + tap_render_frame, 0, buf_idx);
            }
        }

        tap_render_frame += buffer->frame_length();
        if (tapNodeExpectation && tap_render_frame >= length) {
            [tapNodeExpectation fulfill];
            tapNodeExpectation = nil;
        }
    };

    tap->set_render_handler(std::move(tap_render_handler));

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    uint32_t output_render_frame = 0;

    auto render_handler = [&self, &renderExpectation, &output_render_frame, &sample_rate,
                           &format](audio::offline_render_args args) {
        auto &buffer = args.buffer;
        auto const &when = args.when;

        XCTAssertEqual(when.sample_time(), output_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer->frame_length(), frames_per_render);
        XCTAssertTrue(buffer->format() == format);

        for (uint32_t buf_idx = 0; buf_idx < buffer->format().buffer_count(); ++buf_idx) {
            float *ptr = buffer->data_ptr_at_index<float>(buf_idx);
            for (uint32_t frm_idx = 0; frm_idx < buffer->frame_length(); ++frm_idx) {
                bool is_equal_value = ptr[frm_idx] == test::test_value(frm_idx + output_render_frame, 0, buf_idx);
                XCTAssertTrue(is_equal_value);
                if (!is_equal_value) {
                    return audio::continuation::abort;
                }
            }
        }

        output_render_frame += buffer->frame_length();
        if (output_render_frame >= length) {
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
            return audio::continuation::abort;
        }

        return audio::continuation::keep;
    };

    auto completion_handler = [&self, &completionExpectation](bool const cancelled) {
        XCTAssertFalse(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto const device = audio::offline_device::make_shared(format, render_handler, completion_handler);
    auto const offline_io = graph->add_io(device);
    offline_io->raw_io()->set_maximum_frames_per_slice(frames_per_render);

    graph->connect(sample_delay_au->node(), offline_io->node(), format);
    graph->connect(tap->node(), sample_delay_au->node(), format);

    auto start_result = graph->start_render();

    XCTAssertTrue(start_result);

    XCTAssertTrue(graph->io().value()->raw_io()->is_running());

    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    XCTAssertFalse(graph->io().value()->raw_io()->is_running());
}

@end
