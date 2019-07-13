//
//  YASCppAudioUnitTests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_unit_tests : XCTestCase

@end

@implementation yas_audio_unit_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    audio::unit unit(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    XCTAssertTrue(unit);
}

- (void)test_create_null {
    audio::unit unit{nullptr};

    XCTAssertFalse(unit);
}

- (void)test_converter_unit {
    double const output_sample_rate = 44100;
    double const input_sample_rate = 48000;
    uint32_t const channels = 2;
    uint32_t const frame_length = 1024;
    uint32_t const maximum_frame_length = 4096;
    OSType const type = kAudioUnitType_FormatConverter;
    OSType const sub_type = kAudioUnitSubType_AUConverter;

    auto output_format = audio::format({.sample_rate = output_sample_rate,
                                        .channel_count = channels,
                                        .pcm_format = audio::pcm_format::float32,
                                        .interleaved = false});
    auto input_format = audio::format({.sample_rate = input_sample_rate,
                                       .channel_count = channels,
                                       .pcm_format = audio::pcm_format::int16,
                                       .interleaved = true});

    audio::graph graph;

    audio::unit converter_unit(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    converter_unit.set_maximum_frames_per_slice(maximum_frame_length);

    graph.add_unit(converter_unit);

    XCTAssertTrue(converter_unit.is_initialized());
    XCTAssertEqual(converter_unit.type(), type);
    XCTAssertEqual(converter_unit.sub_type(), sub_type);
    XCTAssertFalse(converter_unit.is_output_unit());
    XCTAssertTrue(converter_unit.raw_unit() != NULL);
    XCTAssertEqual(converter_unit.maximum_frames_per_slice(), maximum_frame_length);

    converter_unit.attach_render_callback(0);
    converter_unit.set_output_format(output_format.stream_description(), 0);
    converter_unit.set_input_format(input_format.stream_description(), 0);

    AudioStreamBasicDescription outputASBD = converter_unit.output_format(0);
    XCTAssertTrue(is_equal(output_format.stream_description(), outputASBD));

    AudioStreamBasicDescription inputASBD = converter_unit.input_format(0);
    XCTAssertTrue(is_equal(input_format.stream_description(), inputASBD));

    auto exp = make_objc_ptr<XCTestExpectation *>(
        [&self]() { return [self expectationWithDescription:@"ConverterUnit Render"]; });

    converter_unit.set_render_handler([exp, input_format, &self](audio::render_parameters &render_parameters) mutable {
        if (exp) {
            const AudioBufferList *ioData = render_parameters.io_data;
            XCTAssertNotEqual(ioData, nullptr);
            XCTAssertEqual(ioData->mNumberBuffers, input_format.buffer_count());
            for (uint32_t i = 0; i < input_format.buffer_count(); i++) {
                XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, input_format.stride());
                XCTAssertEqual(ioData->mBuffers[i].mDataByteSize,
                               input_format.buffer_frame_byte_count() * render_parameters.in_number_frames);
            }
            [exp.object() fulfill];

            exp.set_object(nil);
        }
    });

    test::raw_unit_render_on_sub_thread(converter_unit, output_format, frame_length, 1, 0);

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    graph.remove_unit(converter_unit);

    XCTAssertFalse(converter_unit.is_initialized());
}

- (void)test_render_callback {
    double const sampleRate = 44100;
    uint32_t const channels = 2;
    uint32_t const frame_length = 1024;
    uint32_t const maximum_frame_length = 4096;

    auto format = audio::format({.sample_rate = sampleRate,
                                 .channel_count = channels,
                                 .pcm_format = audio::pcm_format::float32,
                                 .interleaved = false});

    audio::graph graph;

    audio::unit converter_unit(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);
    converter_unit.set_maximum_frames_per_slice(maximum_frame_length);

    graph.add_unit(converter_unit);

    converter_unit.attach_render_callback(0);
    converter_unit.attach_render_notify();
    converter_unit.set_output_format(format.stream_description(), 0);
    converter_unit.set_input_format(format.stream_description(), 0);

    auto render_exp = make_objc_ptr<XCTestExpectation *>(
        [&self]() { return [self expectationWithDescription:@"ConverterUnit Render"]; });
    auto pre_render_exp = make_objc_ptr<XCTestExpectation *>(
        [&self]() { return [self expectationWithDescription:@"ConverterUnit PreRender"]; });
    auto post_render_exp = make_objc_ptr<XCTestExpectation *>(
        [&self]() { return [self expectationWithDescription:@"ConverterUnit PostRender"]; });

    converter_unit.set_render_handler([render_exp](audio::render_parameters &render_parameters) mutable {
        if (render_exp) {
            [render_exp.object() fulfill];
            render_exp.set_object(nil);
        }
    });

    converter_unit.set_notify_handler(
        [pre_render_exp, post_render_exp](audio::render_parameters &render_parameters) mutable {
            AudioUnitRenderActionFlags flags = *render_parameters.io_action_flags;
            if (flags & kAudioUnitRenderAction_PreRender) {
                if (pre_render_exp) {
                    [pre_render_exp.object() fulfill];
                    pre_render_exp.set_object(nil);
                }
            } else if (flags & kAudioUnitRenderAction_PostRender) {
                if (post_render_exp) {
                    [post_render_exp.object() fulfill];
                    post_render_exp.set_object(nil);
                }
            }
        });

    test::raw_unit_render_on_sub_thread(converter_unit, format, frame_length, 1, 0);

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    converter_unit.detach_render_notify();
    converter_unit.detach_render_callback(0);

    bool is_render_callback = false;
    bool is_render_notify_callback = false;

    converter_unit.set_render_handler(
        [&is_render_callback](audio::render_parameters &render_parameters) { is_render_callback = true; });

    converter_unit.set_notify_handler([&is_render_notify_callback](audio::render_parameters &render_parameters) {
        is_render_notify_callback = true;
    });

    test::raw_unit_render_on_sub_thread(converter_unit, format, frame_length, 1, 0.2);

    XCTAssertFalse(is_render_callback);
    XCTAssertFalse(is_render_notify_callback);
}

- (void)test_parameter {
    audio::unit delay_unit(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    AudioUnitScope const scope = kAudioUnitScope_Global;
    auto parameter = delay_unit.create_parameter(kDelayParam_DelayTime, scope);

    delay_unit.set_parameter_value(parameter.min_value, kDelayParam_DelayTime, scope, 0);
    XCTAssertEqual(delay_unit.parameter_value(kDelayParam_DelayTime, scope, 0), parameter.min_value);
    delay_unit.set_parameter_value(parameter.max_value, kDelayParam_DelayTime, scope, 0);
    XCTAssertEqual(delay_unit.parameter_value(kDelayParam_DelayTime, scope, 0), parameter.max_value);
    delay_unit.set_parameter_value(parameter.default_value, kDelayParam_DelayTime, scope, 0);
    XCTAssertEqual(delay_unit.parameter_value(kDelayParam_DelayTime, scope, 0), parameter.default_value);

    XCTAssertTrue(parameter.parameter_id != 0);
    XCTAssertTrue(parameter.scope == scope);
    XCTAssertTrue(parameter.unit_name() != nullptr);
    if (parameter.has_clump) {
        XCTAssertTrue(parameter.clump_id != 0);
    }
    XCTAssertTrue(parameter.name() != nullptr);
    XCTAssertTrue(parameter.unit == kAudioUnitParameterUnit_Seconds);
}

- (void)test_parameter_create_failed {
    audio::unit delay_unit(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    XCTAssertThrows(delay_unit.create_parameter(kDelayParam_DelayTime, kAudioUnitScope_Input));
    XCTAssertThrows(delay_unit.create_parameter(kDelayParam_DelayTime, kAudioUnitScope_Output));
}

- (void)test_parameters {
    audio::unit delay_unit(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    auto parameters = delay_unit.create_parameters(kAudioUnitScope_Global);

    XCTAssertEqual(parameters.size(), 4);

    std::vector<AudioUnitParameterID> parameter_ids{kDelayParam_DelayTime, kDelayParam_Feedback,
                                                    kDelayParam_LopassCutoff, kDelayParam_WetDryMix};

    for (auto &parameter : parameters) {
        auto iterator = find(parameter_ids.begin(), parameter_ids.end(), parameter.first);
        XCTAssertTrue(iterator != parameter_ids.end());
    }
}

@end
