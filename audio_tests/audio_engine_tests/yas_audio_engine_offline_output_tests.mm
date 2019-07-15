//
//  yas_audio_offline_output_tests.m
//

#import <future>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_offline_output_tests : XCTestCase

@end

@implementation yas_audio_offline_output_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    audio::engine::offline_output node;

    XCTAssertTrue(node);

    XCTAssertFalse(node.is_running());
    XCTAssertTrue(node.manageable());
}

- (void)test_create_null {
    audio::engine::offline_output node{nullptr};

    XCTAssertFalse(node);
}

- (void)test_offline_render_with_audio_engine {
    double const sample_rate = 44100.0;

    audio::engine::manager manager;
    manager.add_offline_output();

    auto format = audio::format({.sample_rate = sample_rate, .channel_count = 2});
    audio::engine::offline_output &output = manager.offline_output();
    audio::engine::au sample_delay_au(kAudioUnitType_Effect, kAudioUnitSubType_SampleDelay);
    audio::engine::tap tap;

    manager.connect(sample_delay_au.node(), output.node(), format);
    manager.connect(tap.node(), sample_delay_au.node(), format);

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    uint32_t const frames_per_render = 1024;
    uint32_t const length = 4192;
    uint32_t tap_render_frame = 0;

    auto tap_render_handler = [=](audio::engine::node::render_args args) mutable {
        auto &buffer = args.buffer;
        auto const &when = args.when;

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

    tap.set_render_handler(std::move(tap_render_handler));

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    uint32_t output_render_frame = 0;

    auto start_render_handler = [=](audio::engine::offline_render_args args) mutable {
        auto &buffer = args.buffer;
        auto const &when = args.when;

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
                    return audio::continuation::abort;
                }
            }
        }

        output_render_frame += buffer.frame_length();
        if (output_render_frame >= length) {
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
            return audio::continuation::abort;
        }

        return audio::continuation::keep;
    };

    auto completion_handler = [=](bool const cancelled) mutable {
        XCTAssertFalse(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result = manager.start_offline_render(start_render_handler, completion_handler);

    XCTAssertTrue(result);

    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)test_offline_render_without_audio_engine {
    double const sample_rate = 48000.0;
    auto format = audio::format({.sample_rate = sample_rate, .channel_count = 2});
    audio::engine::offline_output output;
    audio::engine::tap tap;

    auto connection = test::connection(tap.node(), 0, output.node(), 0, format);

    output.node().connectable()->add_connection(connection);
    output.node().manageable().update_kernel();
    tap.node().connectable()->add_connection(connection);
    tap.node().manageable().update_kernel();

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    uint32_t const frames_per_render = 1024;
    uint32_t const length = 4196;
    uint32_t tap_render_frame = 0;

    auto tap_render_handler = [=](auto args) mutable {
        auto &buffer = args.buffer;
        auto const &when = args.when;

        XCTAssertEqual(when.sample_time(), tap_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        auto each = audio::make_each_data<float>(buffer);
        while (yas_each_data_next(each)) {
            yas_each_data_value(each) =
                test::test_value((uint32_t)each.frm_idx + tap_render_frame, 0, (uint32_t)each.ptr_idx);
        }

        tap_render_frame += buffer.frame_length();
        if (tap_render_frame && tap_render_frame >= length) {
            [tapNodeExpectation fulfill];
            tapNodeExpectation = nil;
        }
    };

    tap.set_render_handler(std::move(tap_render_handler));

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    uint32_t output_render_frame = 0;

    auto start_render_handler = [=](auto args) mutable {
        auto &buffer = args.buffer;
        auto const &when = args.when;

        XCTAssertEqual(when.sample_time(), output_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        auto each = audio::make_each_data<float>(buffer);
        while (yas_each_data_next(each)) {
            bool is_equal_value =
                yas_each_data_value(each) ==
                test::test_value((uint32_t)each.frm_idx + output_render_frame, 0, (uint32_t)each.ptr_idx);
            XCTAssertTrue(is_equal_value);
            if (!is_equal_value) {
                return audio::continuation::abort;
            }
        }

        output_render_frame += buffer.frame_length();
        if (output_render_frame >= length) {
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
            return audio::continuation::abort;
        }

        return audio::continuation::keep;
    };

    auto completion_handler = [=](bool const cancelled) mutable {
        XCTAssertFalse(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result = output.manageable().start(std::move(start_render_handler), std::move(completion_handler));

    XCTAssertTrue(result);

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count {
    audio::engine::offline_output output;

    XCTAssertEqual(output.node().output_bus_count(), 0);
    XCTAssertEqual(output.node().input_bus_count(), 1);
}

- (void)test_reset_to_stop {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    audio::engine::offline_output output;
    audio::engine::tap tap;

    auto connection = test::connection(tap.node(), 0, output.node(), 0, format);

    output.node().connectable()->add_connection(connection);
    output.node().manageable().update_kernel();
    tap.node().connectable()->add_connection(connection);
    tap.node().manageable().update_kernel();

    auto promise = std::make_shared<std::promise<void>>();
    auto future = promise->get_future();

    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    auto render_handler = [promise](auto args) mutable {
        if (args.when.sample_time() == 0) {
            promise->set_value();
        }
        return audio::continuation::keep;
    };

    auto completion_handler = [=](bool const cancelled) mutable {
        XCTAssertTrue(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result = output.manageable().start(std::move(render_handler), completion_handler);

    XCTAssertTrue(result);

    future.get();

    output.node().reset();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_offline_start_error_to_string {
    XCTAssertTrue(to_string(audio::engine::offline_start_error_t::already_running) == "already_running");
    XCTAssertTrue(to_string(audio::engine::offline_start_error_t::prepare_failure) == "prepare_failure");
    XCTAssertTrue(to_string(audio::engine::offline_start_error_t::connection_not_found) == "connection_not_found");
}

- (void)test_offline_start_error_ostream {
    auto const errors = {audio::engine::offline_start_error_t::already_running,
                         audio::engine::offline_start_error_t::prepare_failure,
                         audio::engine::offline_start_error_t::connection_not_found};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

@end
