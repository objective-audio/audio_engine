//
//  yas_audio_offline_output_node_tests.m
//

#import <future>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_offline_output_node_tests : XCTestCase

@end

@implementation yas_audio_offline_output_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_offline_render_with_audio_engine {
    double const sample_rate = 44100.0;

    auto format = audio::format(sample_rate, 2);
    audio::engine engine;
    audio::offline_output_node output_node;
    audio::unit_node sample_delay_node(kAudioUnitType_Effect, kAudioUnitSubType_SampleDelay);
    audio::tap_node tap_node;

    engine.connect(sample_delay_node, output_node, format);
    engine.connect(tap_node, sample_delay_node, format);

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    uint32_t const frames_per_render = 1024;
    uint32_t const length = 4192;
    uint32_t tap_render_frame = 0;

    auto tap_render_function = [=](audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when) mutable {
        XCTAssertEqual(when.sample_time(), tap_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        for (uint32_t buf_idx = 0; buf_idx < buffer.format().buffer_count(); ++buf_idx) {
            float *ptr = buffer.data_ptr_at_index<float>(buf_idx);
            for (uint32_t frm_idx = 0; frm_idx < buffer.frame_length(); ++frm_idx) {
                ptr[frm_idx] = test::test_value(frm_idx + tap_render_frame, 0, buf_idx);
            }
        }

        tap_render_frame += buffer.frame_length();
        if (tapNodeExpectation && tap_render_frame >= length) {
            [tapNodeExpectation fulfill];
            tapNodeExpectation = nil;
        }
    };

    tap_node.set_render_function(std::move(tap_render_function));

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    uint32_t output_render_frame = 0;

    auto start_render_function = [=](audio::pcm_buffer &buffer, audio::time const &when, bool &out_stop) mutable {
        XCTAssertEqual(when.sample_time(), output_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        for (uint32_t buf_idx = 0; buf_idx < buffer.format().buffer_count(); ++buf_idx) {
            float *ptr = buffer.data_ptr_at_index<float>(buf_idx);
            for (uint32_t frm_idx = 0; frm_idx < buffer.frame_length(); ++frm_idx) {
                bool is_equal_value = ptr[frm_idx] == test::test_value(frm_idx + output_render_frame, 0, buf_idx);
                XCTAssertTrue(is_equal_value);
                if (!is_equal_value) {
                    out_stop = true;
                    return;
                }
            }
        }

        output_render_frame += buffer.frame_length();
        if (output_render_frame >= length) {
            out_stop = true;
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
        }
    };

    auto completion_function = [=](bool const cancelled) mutable {
        XCTAssertFalse(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result = engine.start_offline_render(start_render_function, completion_function);

    XCTAssertTrue(result);

    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)test_offline_render_without_audio_engine {
    double const sample_rate = 48000.0;
    auto format = audio::format(sample_rate, 2);
    audio::offline_output_node output_node;
    audio::tap_node tap_node;

    auto connection = audio::connection::private_access::create(tap_node, 0, output_node, 0, format);

    output_node.manageable_node().add_connection(connection);
    output_node.manageable_node().update_kernel();
    tap_node.manageable_node().add_connection(connection);
    tap_node.manageable_node().update_kernel();

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    uint32_t const frames_per_render = 1024;
    uint32_t const length = 4196;
    uint32_t tap_render_frame = 0;

    auto tap_render_function = [=](audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when) mutable {
        XCTAssertEqual(when.sample_time(), tap_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        auto enumerator = audio::frame_enumerator(buffer);
        auto *flex_ptr = enumerator.pointer();
        auto *frm_idx = enumerator.frame();
        auto *ch_idx = enumerator.channel();
        while (flex_ptr->v) {
            *flex_ptr->f32 = test::test_value(*frm_idx + tap_render_frame, 0, *ch_idx);
            yas_audio_frame_enumerator_move(enumerator);
        }

        tap_render_frame += buffer.frame_length();
        if (tap_render_frame && tap_render_frame >= length) {
            [tapNodeExpectation fulfill];
            tapNodeExpectation = nil;
        }
    };

    tap_node.set_render_function(std::move(tap_render_function));

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    uint32_t output_render_frame = 0;

    auto start_render_function = [=](audio::pcm_buffer &buffer, audio::time const &when, bool &out_stop) mutable {
        XCTAssertEqual(when.sample_time(), output_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        auto enumerator = audio::frame_enumerator(buffer);

        auto *flex_ptr = enumerator.pointer();
        auto *frm_idx = enumerator.frame();
        auto *ch_idx = enumerator.channel();
        while (flex_ptr->v) {
            bool is_equal_value = *flex_ptr->f32 == test::test_value(*frm_idx + output_render_frame, 0, *ch_idx);
            XCTAssertTrue(is_equal_value);
            if (!is_equal_value) {
                out_stop = YES;
                return;
            }
            yas_audio_frame_enumerator_move(enumerator);
        }

        output_render_frame += buffer.frame_length();
        if (output_render_frame >= length) {
            out_stop = true;
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
        }
    };

    auto completion_function = [=](bool const cancelled) mutable {
        XCTAssertFalse(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result = output_node.manageable_offline_output_unit().start(std::move(start_render_function),
                                                                     std::move(completion_function));

    XCTAssertTrue(result);

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count {
    audio::offline_output_node node;

    XCTAssertEqual(node.output_bus_count(), 0);
    XCTAssertEqual(node.input_bus_count(), 1);
}

- (void)test_reset_to_stop {
    auto format = audio::format(48000.0, 2);
    audio::offline_output_node output_node;
    audio::tap_node tap_node;

    auto connection = audio::connection::private_access::create(tap_node, 0, output_node, 0, format);

    output_node.manageable_node().add_connection(connection);
    output_node.manageable_node().update_kernel();
    tap_node.manageable_node().add_connection(connection);
    tap_node.manageable_node().update_kernel();

    auto promise = std::make_shared<std::promise<void>>();
    auto future = promise->get_future();

    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    auto render_func = [promise](audio::pcm_buffer &buffer, audio::time const &when, bool &out_stop) mutable {
        if (when.sample_time() == 0) {
            promise->set_value();
        }
    };

    auto completion_function = [=](bool const cancelled) mutable {
        XCTAssertTrue(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result = output_node.manageable_offline_output_unit().start(std::move(render_func), completion_function);

    XCTAssertTrue(result);

    future.get();

    output_node.reset();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_to_string_error {
    XCTAssertTrue(to_string(audio::offline_start_error_t::already_running) == "already_running");
    XCTAssertTrue(to_string(audio::offline_start_error_t::prepare_failure) == "prepare_failure");
    XCTAssertTrue(to_string(audio::offline_start_error_t::connection_not_found) == "connection_not_found");
}

@end
