//
//  YASCppAudioGraphTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio_graph.h"
#import "yas_audio_unit.h"
#import "yas_audio_format.h"
#import "yas_audio_time.h"
#import "yas_audio_pcm_buffer.h"
#import "YASMacros.h"

@interface yas_audio_graph_tests : XCTestCase

@end

@implementation yas_audio_graph_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRunning
{
    auto audio_graph = yas::audio_graph::create();

    audio_graph->start();

    XCTAssertTrue(audio_graph->is_running());

    audio_graph->stop();

    XCTAssertFalse(audio_graph->is_running());
}

- (void)testIORendering
{
    const Float64 output_sample_rate = 48000;
    const Float64 mixer_sample_rate = 44100;
    const UInt32 channels = 2;
    const UInt32 frame_length = 1024;
    const UInt32 maximum_frame_length = 4096;

    auto output_format = yas::audio_format::create(output_sample_rate, channels);
    auto mixer_format = yas::audio_format::create(mixer_sample_rate, channels);

    const auto audio_graph = yas::audio_graph::create();
    auto io_unit = yas::audio_unit::create(kAudioUnitType_Output, kAudioUnitSubType_GenericOutput);
    io_unit->set_maximum_frames_per_slice(maximum_frame_length);
    audio_graph->add_audio_unit(io_unit);

    io_unit->attach_render_callback(0);

    const UInt32 mixerInputCount = 16;

    auto mixer_unit = yas::audio_unit::create(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
    mixer_unit->set_maximum_frames_per_slice(maximum_frame_length);
    audio_graph->add_audio_unit(mixer_unit);

    mixer_unit->set_output_format(mixer_format->stream_description(), 0);

    AudioStreamBasicDescription outputASBD = mixer_unit->output_format(0);
    XCTAssertEqual(outputASBD.mSampleRate, mixer_sample_rate);

    mixer_unit->set_element_count(4, kAudioUnitScope_Input);
    XCTAssertNotEqual(mixer_unit->element_count(kAudioUnitScope_Input), 4);  // Under 8
    XCTAssertEqual(mixer_unit->element_count(kAudioUnitScope_Input), 8);

    mixer_unit->set_element_count(mixerInputCount, kAudioUnitScope_Input);
    XCTAssertEqual(mixer_unit->element_count(kAudioUnitScope_Input), mixerInputCount);

    for (UInt32 i = 0; i < mixerInputCount; i++) {
        mixer_unit->attach_render_callback(i);

        mixer_unit->set_input_format(output_format->stream_description(), i);
        AudioStreamBasicDescription input_asbd = mixer_unit->input_format(i);
        XCTAssertEqual(input_asbd.mSampleRate, output_sample_rate);

        mixer_unit->set_input_format(mixer_format->stream_description(), i);
        input_asbd = mixer_unit->input_format(i);
        XCTAssertEqual(input_asbd.mSampleRate, mixer_sample_rate);
    }

    XCTestExpectation *ioExpectation = [self expectationWithDescription:@"io_unit render"];
    YASRetainOrIgnore(ioExpectation);

    io_unit->set_render_callback([ioExpectation, frame_length, output_format, &mixer_unit, &self](
        yas::render_parameters &render_parameters) mutable {
        if (ioExpectation) {
            [ioExpectation fulfill];

            XCTAssertEqual(render_parameters.in_number_frames, frame_length);
            XCTAssertEqual(render_parameters.in_bus_number, 0);
            XCTAssertEqual(render_parameters.in_render_type, yas::render_type::normal);
            XCTAssertEqual(*render_parameters.io_action_flags, 0);
            const AudioBufferList *ioData = render_parameters.io_data;
            XCTAssertNotEqual(ioData, nullptr);
            XCTAssertEqual(ioData->mNumberBuffers, output_format->buffer_count());
            for (UInt32 i = 0; i < output_format->buffer_count(); i++) {
                XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, output_format->stride());
                XCTAssertEqual(
                    ioData->mBuffers[i].mDataByteSize,
                    output_format->sample_byte_count() * output_format->stride() * render_parameters.in_number_frames);
            }

            mixer_unit->audio_unit_render(render_parameters);

            YASRelease(ioExpectation);
            ioExpectation = nil;
        }
    });

    NSMutableDictionary *mixerExpectations = [NSMutableDictionary dictionaryWithCapacity:mixerInputCount];
    for (UInt32 i = 0; i < mixerInputCount; i++) {
        NSString *description = [NSString stringWithFormat:@"MixerUnit Render Bus=%@", @(i)];
        mixerExpectations[@(i)] = [self expectationWithDescription:description];
    }

    YASRetainOrIgnore(mixerExpectations);

    mixer_unit->set_render_callback(
        [mixerExpectations, output_format, frame_length, &self](yas::render_parameters &render_parameters) mutable {
            if (mixerExpectations) {
                const UInt32 bus = render_parameters.in_bus_number;
                NSNumber *busKey = @(bus);
                XCTestExpectation *mixerExpectation = mixerExpectations[busKey];
                if (mixerExpectations) {
                    [mixerExpectation fulfill];
                    [mixerExpectations removeObjectForKey:busKey];

                    XCTAssertEqual(render_parameters.in_number_frames, frame_length);
                    XCTAssertEqual(render_parameters.in_render_type, yas::render_type::normal);
                    XCTAssertEqual(*render_parameters.io_action_flags, 0);
                    const AudioBufferList *ioData = render_parameters.io_data;
                    XCTAssertNotEqual(ioData, nullptr);
                    XCTAssertEqual(ioData->mNumberBuffers, output_format->buffer_count());
                    for (UInt32 i = 0; i < output_format->buffer_count(); i++) {
                        XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, output_format->stride());
                        XCTAssertEqual(ioData->mBuffers[i].mDataByteSize, output_format->sample_byte_count() *
                                                                              output_format->stride() *
                                                                              render_parameters.in_number_frames);
                    }
                }

                if (mixerExpectations.count == 0) {
                    YASRelease(mixerExpectations);
                    mixerExpectations = nil;
                }
            }
        });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   [io_unit, output_format, output_sample_rate]() {
                       AudioUnitRenderActionFlags actionFlags = 0;
                       yas::audio_time audio_time(0, output_sample_rate);
                       AudioTimeStamp timeStamp = audio_time.audio_time_stamp();

                       auto data = yas::audio_pcm_buffer::create(output_format, frame_length);

                       yas::render_parameters parameters = {
                           .in_render_type = yas::render_type::normal,
                           .io_action_flags = &actionFlags,
                           .io_time_stamp = &timeStamp,
                           .in_bus_number = 0,
                           .in_number_frames = 1024,
                           .io_data = data->audio_buffer_list(),
                       };

                       io_unit->audio_unit_render(parameters);
                   });

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];
}

@end
