//
//  yas_audio_offline_output_node_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"
#import <future>

@interface yas_audio_offline_output_node_tests : XCTestCase

@end

@implementation yas_audio_offline_output_node_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_offline_render_with_audio_engine
{
    const Float64 sample_rate = 44100.0;

    auto format = yas::audio_format(sample_rate, 2);
    yas::audio_engine engine;
    yas::audio_offline_output_node output_node;
    yas::audio_unit_node sample_delay_node(kAudioUnitType_Effect, kAudioUnitSubType_SampleDelay);
    yas::audio_tap_node tap_node;

    engine.connect(sample_delay_node, output_node, format);
    engine.connect(tap_node, sample_delay_node, format);

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    const UInt32 frames_per_render = 1024;
    const UInt32 length = 4192;
    UInt32 tap_render_frame = 0;

    auto tap_render_function =
        [=](yas::audio_pcm_buffer &buffer, const UInt32 bus_idx, const yas::audio_time &when) mutable {
            XCTAssertEqual(when.sample_time(), tap_render_frame);
            XCTAssertEqual(when.sample_rate(), sample_rate);
            XCTAssertEqual(buffer.frame_length(), frames_per_render);
            XCTAssertTrue(buffer.format() == format);

            for (UInt32 buf_idx = 0; buf_idx < buffer.format().buffer_count(); ++buf_idx) {
                Float32 *ptr = buffer.data_ptr_at_index<Float32>(buf_idx);
                for (UInt32 frm_idx = 0; frm_idx < buffer.frame_length(); ++frm_idx) {
                    ptr[frm_idx] = yas::test::test_value(frm_idx + tap_render_frame, 0, buf_idx);
                }
            }

            tap_render_frame += buffer.frame_length();
            if (tapNodeExpectation && tap_render_frame >= length) {
                [tapNodeExpectation fulfill];
                tapNodeExpectation = nil;
            }
        };

    tap_node.set_render_function(tap_render_function);

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    UInt32 output_render_frame = 0;

    auto start_render_function = [=](yas::audio_pcm_buffer &buffer, const yas::audio_time &when, bool &stop) mutable {
        XCTAssertEqual(when.sample_time(), output_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        for (UInt32 buf_idx = 0; buf_idx < buffer.format().buffer_count(); ++buf_idx) {
            Float32 *ptr = buffer.data_ptr_at_index<Float32>(buf_idx);
            for (UInt32 frm_idx = 0; frm_idx < buffer.frame_length(); ++frm_idx) {
                bool is_equal_value = ptr[frm_idx] == yas::test::test_value(frm_idx + output_render_frame, 0, buf_idx);
                XCTAssertTrue(is_equal_value);
                if (!is_equal_value) {
                    stop = true;
                    return;
                }
            }
        }

        output_render_frame += buffer.frame_length();
        if (output_render_frame >= length) {
            stop = true;
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
        }
    };

    auto completion_function = [=](const bool cancelled) mutable {
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

- (void)test_offline_render_without_audio_engine
{
    const Float64 sample_rate = 48000.0;
    auto format = yas::audio_format(sample_rate, 2);
    yas::audio_offline_output_node output_node;
    yas::audio_tap_node tap_node;

    auto connection = yas::audio_connection::private_access::create(tap_node, 0, output_node, 0, format);

    yas::audio_node::private_access::add_connection(output_node, connection);
    yas::audio_node::private_access::update_kernel(output_node);
    yas::audio_node::private_access::add_connection(tap_node, connection);
    yas::audio_node::private_access::update_kernel(tap_node);

    XCTestExpectation *tapNodeExpectation = [self expectationWithDescription:@"tap node render"];

    const UInt32 frames_per_render = 1024;
    const UInt32 length = 4196;
    UInt32 tap_render_frame = 0;

    auto tap_render_function =
        [=](yas::audio_pcm_buffer &buffer, const UInt32 bus_idx, const yas::audio_time &when) mutable {
            XCTAssertEqual(when.sample_time(), tap_render_frame);
            XCTAssertEqual(when.sample_rate(), sample_rate);
            XCTAssertEqual(buffer.frame_length(), frames_per_render);
            XCTAssertTrue(buffer.format() == format);

            auto enumerator = yas::audio_frame_enumerator(buffer);
            auto *flex_ptr = enumerator.pointer();
            auto *frm_idx = enumerator.frame();
            auto *ch_idx = enumerator.channel();
            while (flex_ptr->v) {
                *flex_ptr->f32 = yas::test::test_value(*frm_idx + tap_render_frame, 0, *ch_idx);
                yas_audio_frame_enumerator_move(enumerator);
            }

            tap_render_frame += buffer.frame_length();
            if (tap_render_frame && tap_render_frame >= length) {
                [tapNodeExpectation fulfill];
                tapNodeExpectation = nil;
            }
        };

    tap_node.set_render_function(tap_render_function);

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"offline output node render"];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    UInt32 output_render_frame = 0;

    auto start_render_function = [=](yas::audio_pcm_buffer &buffer, const yas::audio_time &when, bool &stop) mutable {
        XCTAssertEqual(when.sample_time(), output_render_frame);
        XCTAssertEqual(when.sample_rate(), sample_rate);
        XCTAssertEqual(buffer.frame_length(), frames_per_render);
        XCTAssertTrue(buffer.format() == format);

        auto enumerator = yas::audio_frame_enumerator(buffer);

        auto *flex_ptr = enumerator.pointer();
        auto *frm_idx = enumerator.frame();
        auto *ch_idx = enumerator.channel();
        while (flex_ptr->v) {
            bool is_equal_value = *flex_ptr->f32 == yas::test::test_value(*frm_idx + output_render_frame, 0, *ch_idx);
            XCTAssertTrue(is_equal_value);
            if (!is_equal_value) {
                stop = YES;
                return;
            }
            yas_audio_frame_enumerator_move(enumerator);
        }

        output_render_frame += buffer.frame_length();
        if (output_render_frame >= length) {
            stop = true;
            if (renderExpectation) {
                [renderExpectation fulfill];
                renderExpectation = nil;
            }
        }
    };

    auto completion_function = [=](const bool cancelled) mutable {
        XCTAssertFalse(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result =
        yas::audio_offline_output_node::private_access::start(output_node, start_render_function, completion_function);

    XCTAssertTrue(result);

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count
{
    yas::audio_offline_output_node node;

    XCTAssertEqual(node.output_bus_count(), 0);
    XCTAssertEqual(node.input_bus_count(), 1);
}

- (void)test_reset_to_stop
{
    auto format = yas::audio_format(48000.0, 2);
    yas::audio_offline_output_node output_node;
    yas::audio_tap_node tap_node;

    auto connection = yas::audio_connection::private_access::create(tap_node, 0, output_node, 0, format);

    yas::audio_node::private_access::add_connection(output_node, connection);
    yas::audio_node::private_access::update_kernel(output_node);
    yas::audio_node::private_access::add_connection(tap_node, connection);
    yas::audio_node::private_access::update_kernel(tap_node);

    auto promise = std::make_shared<std::promise<bool>>();
    auto future = promise->get_future();

    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"offline output node completion"];

    auto render_func = [promise](yas::audio_pcm_buffer &buffer, const yas::audio_time &when, bool &stop) mutable {
        if (when.sample_time() == 0) {
            promise->set_value(true);
        }
    };

    auto completion_function = [=](const bool cancelled) mutable {
        XCTAssertTrue(cancelled);
        if (completionExpectation) {
            [completionExpectation fulfill];
            completionExpectation = nil;
        }
    };

    auto result =
        yas::audio_offline_output_node::private_access::start(output_node, std::move(render_func), completion_function);

    XCTAssertTrue(result);
    XCTAssertTrue(future.get());

    output_node.reset();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];
}

@end
