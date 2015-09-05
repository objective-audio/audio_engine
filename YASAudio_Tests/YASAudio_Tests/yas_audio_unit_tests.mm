//
//  YASCppAudioUnitTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import <iostream>
#import "yas_audio_graph.h"
#import "yas_audio_unit.h"
#import "yas_audio_unit_parameter.h"
#import "yas_audio_format.h"
#import "YASMacros.h"
#import "yas_audio_test_utils.h"

@interface yas_audio_unit_tests : XCTestCase

@end

@implementation yas_audio_unit_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testConverterUnit
{
    const Float64 output_sample_rate = 44100;
    const Float64 input_sample_rate = 48000;
    const UInt32 channels = 2;
    const UInt32 frame_length = 1024;
    const UInt32 maximum_frame_length = 4096;
    const OSType type = kAudioUnitType_FormatConverter;
    const OSType sub_type = kAudioUnitSubType_AUConverter;

    auto output_format = yas::audio_format::create(output_sample_rate, channels, yas::pcm_format::float32, false);
    auto input_format = yas::audio_format::create(input_sample_rate, channels, yas::pcm_format::int16, true);

    const auto audio_graph = yas::audio_graph::create();
    auto converter_unit = yas::audio_unit::create(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    converter_unit->set_maximum_frames_per_slice(maximum_frame_length);
    audio_graph->add_audio_unit(converter_unit);

    XCTAssertTrue(converter_unit->is_initialized());
    XCTAssertEqual(converter_unit->type(), type);
    XCTAssertEqual(converter_unit->sub_type(), sub_type);
    XCTAssertFalse(converter_unit->is_output_unit());
    XCTAssertTrue(converter_unit->audio_unit_instance() != NULL);
    XCTAssertEqual(converter_unit->maximum_frames_per_slice(), maximum_frame_length);

    converter_unit->attach_render_callback(0);
    converter_unit->set_output_format(output_format->stream_description(), 0);
    converter_unit->set_input_format(input_format->stream_description(), 0);

    AudioStreamBasicDescription outputASBD = converter_unit->output_format(0);
    XCTAssertTrue(yas::is_equal(output_format->stream_description(), outputASBD));

    AudioStreamBasicDescription inputASBD = converter_unit->input_format(0);
    XCTAssertTrue(yas::is_equal(input_format->stream_description(), inputASBD));

    XCTestExpectation *expectation = [self expectationWithDescription:@"ConverterUnit Render"];

    YASRetainOrIgnore(expectation);

    converter_unit->set_render_callback(
        [expectation, input_format, &self](yas::render_parameters &render_parameters) mutable {
            if (expectation) {
                const AudioBufferList *ioData = render_parameters.io_data;
                XCTAssertNotEqual(ioData, nullptr);
                XCTAssertEqual(ioData->mNumberBuffers, input_format->buffer_count());
                for (UInt32 i = 0; i < input_format->buffer_count(); i++) {
                    XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, input_format->stride());
                    XCTAssertEqual(ioData->mBuffers[i].mDataByteSize,
                                   input_format->buffer_frame_byte_count() * render_parameters.in_number_frames);
                }
                [expectation fulfill];

                YASRelease(expectation);
                expectation = nil;
            }
        });

    yas::test::audio_unit_render_on_sub_thread(converter_unit, output_format, frame_length, 1, 0);

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    audio_graph->remove_audio_unit(converter_unit);

    XCTAssertFalse(converter_unit->is_initialized());
}

- (void)testRenderCallback
{
    const Float64 sampleRate = 44100;
    const UInt32 channels = 2;
    const UInt32 frame_length = 1024;
    const UInt32 maximum_frame_length = 4096;

    auto format = yas::audio_format::create(sampleRate, channels, yas::pcm_format::float32, false);

    const auto audio_graph = yas::audio_graph::create();
    auto converter_unit = yas::audio_unit::create(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    converter_unit->set_maximum_frames_per_slice(maximum_frame_length);
    audio_graph->add_audio_unit(converter_unit);

    converter_unit->attach_render_callback(0);
    converter_unit->attach_render_notify();
    converter_unit->set_output_format(format->stream_description(), 0);
    converter_unit->set_input_format(format->stream_description(), 0);

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"ConverterUnit Render"];
    XCTestExpectation *preRenderExpectation = [self expectationWithDescription:@"ConverterUnit PreRender"];
    XCTestExpectation *postRenderExpectation = [self expectationWithDescription:@"ConverterUnit PostRender"];

    YASRetainOrIgnore(renderExpectation);
    YASRetainOrIgnore(preRenderExpectation);
    YASRetainOrIgnore(postRenderExpectation);

    converter_unit->set_render_callback([renderExpectation](yas::render_parameters &render_parameters) mutable {
        if (renderExpectation) {
            [renderExpectation fulfill];
            YASRelease(renderExpectation);
            renderExpectation = nil;
        }
    });

    converter_unit->set_notify_callback(
        [preRenderExpectation, postRenderExpectation](yas::render_parameters &render_parameters) mutable {
            AudioUnitRenderActionFlags flags = *render_parameters.io_action_flags;
            if (flags & kAudioUnitRenderAction_PreRender) {
                if (preRenderExpectation) {
                    [preRenderExpectation fulfill];
                    YASRelease(preRenderExpectation);
                    preRenderExpectation = nil;
                }
            } else if (flags & kAudioUnitRenderAction_PostRender) {
                if (postRenderExpectation) {
                    [postRenderExpectation fulfill];
                    YASRelease(postRenderExpectation);
                    postRenderExpectation = nil;
                }
            }
        });

    yas::test::audio_unit_render_on_sub_thread(converter_unit, format, frame_length, 1, 0);

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    converter_unit->detach_render_notify();
    converter_unit->detach_render_callback(0);

    bool is_render_callback = false;
    bool is_render_notify_callback = false;

    converter_unit->set_render_callback(
        [&is_render_callback](yas::render_parameters &render_parameters) { is_render_callback = true; });

    converter_unit->set_notify_callback(
        [&is_render_notify_callback](yas::render_parameters &render_parameters) { is_render_notify_callback = true; });

    yas::test::audio_unit_render_on_sub_thread(converter_unit, format, frame_length, 1, 0.2);

    XCTAssertFalse(is_render_callback);
    XCTAssertFalse(is_render_notify_callback);
}

- (void)testParameter
{
    auto delay_unit = yas::audio_unit::create(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    auto delay_time_parameter = delay_unit->create_parameter(kDelayParam_DelayTime, kAudioUnitScope_Global);
    const AudioUnitParameterValue min = delay_time_parameter.min_value();
    const AudioUnitParameterValue value = min;
    const AudioUnitScope scope = kAudioUnitScope_Global;

    delay_unit->set_parameter_value(value, kDelayParam_DelayTime, scope, 0);
    XCTAssertEqual(delay_unit->parameter_value(kDelayParam_DelayTime, scope, 0), value);

    XCTAssertThrows(delay_time_parameter = delay_unit->create_parameter(kDelayParam_DelayTime, kAudioUnitScope_Input));
    XCTAssertThrows(delay_time_parameter = delay_unit->create_parameter(kDelayParam_DelayTime, kAudioUnitScope_Output));
}

- (void)testParameters
{
    auto delay_unit = yas::audio_unit::create(kAudioUnitType_Effect, kAudioUnitSubType_Delay);

    auto parameters = delay_unit->create_parameters(kAudioUnitScope_Global);

    XCTAssertEqual(parameters.size(), 4);

    std::vector<AudioUnitParameterID> parameter_ids{kDelayParam_DelayTime, kDelayParam_Feedback,
                                                    kDelayParam_LopassCutoff, kDelayParam_WetDryMix};

    for (auto &parameter : parameters) {
        auto iterator = find(parameter_ids.begin(), parameter_ids.end(), parameter.first);
        XCTAssertTrue(iterator != parameter_ids.end());
    }
}

- (void)testPropertyData
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 4;
    const AudioUnitPropertyID property_id = kAudioUnitProperty_StreamFormat;
    const AudioUnitScope scope = kAudioUnitScope_Input;
    const AudioUnitElement element = 0;

    auto format = yas::audio_format::create(sampleRate, channels, yas::pcm_format::float32, false);

    std::vector<AudioStreamBasicDescription> set_data;
    set_data.push_back(format->stream_description());

    auto converter_unit = yas::audio_unit::create(kAudioUnitType_FormatConverter, kAudioUnitSubType_AUConverter);

    converter_unit->set_property_data(set_data, property_id, scope, element);

    std::vector<AudioStreamBasicDescription> get_data;

    XCTAssertNoThrow(get_data =
                         converter_unit->property_data<AudioStreamBasicDescription>(property_id, scope, element));

    XCTAssertTrue(yas::is_equal(set_data.at(0), get_data.at(0)));

    std::vector<AudioStreamBasicDescription> zero_data;
    XCTAssertThrows(converter_unit->set_property_data(zero_data, property_id, scope, element));
}

@end
