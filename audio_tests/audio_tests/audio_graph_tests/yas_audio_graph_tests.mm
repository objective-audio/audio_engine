//
//  YASCppAudioGraphTests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_tests : XCTestCase

@end

@implementation yas_audio_graph_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_running {
    audio::graph graph;

    graph.start();

    XCTAssertTrue(graph.is_running());

    graph.stop();

    XCTAssertFalse(graph.is_running());
}

- (void)test_io_rendering {
    double const output_sample_rate = 48000;
    double const mixer_sample_rate = 44100;
    uint32_t const channels = 2;
    uint32_t const frame_length = 1024;
    uint32_t const maximum_frame_length = 4096;

    auto output_format = audio::format({.sample_rate = output_sample_rate, .channel_count = channels});
    auto mixer_format = audio::format({.sample_rate = mixer_sample_rate, .channel_count = channels});

    audio::graph graph;

    audio::unit io_unit(kAudioUnitType_Output, kAudioUnitSubType_GenericOutput);
    io_unit.set_maximum_frames_per_slice(maximum_frame_length);
    graph.add_audio_unit(io_unit);

    io_unit.attach_render_callback(0);

    uint32_t const mixerInputCount = 16;

    audio::unit mixer_unit(kAudioUnitType_Mixer, kAudioUnitSubType_MultiChannelMixer);
    mixer_unit.set_maximum_frames_per_slice(maximum_frame_length);
    graph.add_audio_unit(mixer_unit);

    mixer_unit.set_output_format(mixer_format.stream_description(), 0);

    AudioStreamBasicDescription outputASBD = mixer_unit.output_format(0);
    XCTAssertEqual(outputASBD.mSampleRate, mixer_sample_rate);

    mixer_unit.set_element_count(4, kAudioUnitScope_Input);
    XCTAssertNotEqual(mixer_unit.element_count(kAudioUnitScope_Input), 4);  // Under 8
    XCTAssertEqual(mixer_unit.element_count(kAudioUnitScope_Input), 8);

    mixer_unit.set_element_count(mixerInputCount, kAudioUnitScope_Input);
    XCTAssertEqual(mixer_unit.element_count(kAudioUnitScope_Input), mixerInputCount);

    for (uint32_t i = 0; i < mixerInputCount; i++) {
        mixer_unit.attach_render_callback(i);

        mixer_unit.set_input_format(output_format.stream_description(), i);
        AudioStreamBasicDescription input_asbd = mixer_unit.input_format(i);
        XCTAssertEqual(input_asbd.mSampleRate, output_sample_rate);

        mixer_unit.set_input_format(mixer_format.stream_description(), i);
        input_asbd = mixer_unit.input_format(i);
        XCTAssertEqual(input_asbd.mSampleRate, mixer_sample_rate);
    }

    XCTestExpectation *ioExpectation = [self expectationWithDescription:@"io_unit render"];
    yas_retain_or_ignore(ioExpectation);

    io_unit.set_render_handler([ioExpectation, frame_length, output_format, &mixer_unit,
                                &self](audio::render_parameters &render_parameters) mutable {
        if (ioExpectation) {
            [ioExpectation fulfill];

            XCTAssertEqual(render_parameters.in_number_frames, frame_length);
            XCTAssertEqual(render_parameters.in_bus_number, 0);
            XCTAssertEqual(render_parameters.in_render_type, audio::render_type::normal);
            XCTAssertEqual(*render_parameters.io_action_flags, 0);
            AudioBufferList const *ioData = render_parameters.io_data;
            XCTAssertNotEqual(ioData, nullptr);
            XCTAssertEqual(ioData->mNumberBuffers, output_format.buffer_count());
            for (uint32_t i = 0; i < output_format.buffer_count(); i++) {
                XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, output_format.stride());
                XCTAssertEqual(
                    ioData->mBuffers[i].mDataByteSize,
                    output_format.sample_byte_count() * output_format.stride() * render_parameters.in_number_frames);
            }

            mixer_unit.raw_unit_render(render_parameters);

            yas_release(ioExpectation);
            ioExpectation = nil;
        }
    });

    NSMutableDictionary *mixerExpectations = [NSMutableDictionary dictionaryWithCapacity:mixerInputCount];
    for (uint32_t i = 0; i < mixerInputCount; i++) {
        NSString *description = [NSString stringWithFormat:@"MixerUnit Render Bus=%@", @(i)];
        mixerExpectations[@(i)] = [self expectationWithDescription:description];
    }

    yas_retain_or_ignore(mixerExpectations);

    mixer_unit.set_render_handler(
        [mixerExpectations, output_format, frame_length, &self](audio::render_parameters &render_parameters) mutable {
            if (mixerExpectations) {
                uint32_t const bus_idx = render_parameters.in_bus_number;
                NSNumber *busKey = @(bus_idx);
                XCTestExpectation *mixerExpectation = mixerExpectations[busKey];
                if (mixerExpectations) {
                    [mixerExpectation fulfill];
                    [mixerExpectations removeObjectForKey:busKey];

                    XCTAssertEqual(render_parameters.in_number_frames, frame_length);
                    XCTAssertEqual(render_parameters.in_render_type, audio::render_type::normal);
                    XCTAssertEqual(*render_parameters.io_action_flags, 0);
                    AudioBufferList const *ioData = render_parameters.io_data;
                    XCTAssertNotEqual(ioData, nullptr);
                    XCTAssertEqual(ioData->mNumberBuffers, output_format.buffer_count());
                    for (uint32_t i = 0; i < output_format.buffer_count(); i++) {
                        XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, output_format.stride());
                        XCTAssertEqual(ioData->mBuffers[i].mDataByteSize, output_format.sample_byte_count() *
                                                                              output_format.stride() *
                                                                              render_parameters.in_number_frames);
                    }
                }

                if (mixerExpectations.count == 0) {
                    yas_release(mixerExpectations);
                    mixerExpectations = nil;
                }
            }
        });

    auto dispatch_labmda = [io_unit, output_format, output_sample_rate]() mutable {
        AudioUnitRenderActionFlags actionFlags = 0;
        audio::time time(0, output_sample_rate);
        AudioTimeStamp timeStamp = time.audio_time_stamp();

        audio::pcm_buffer buffer(output_format, frame_length);

        audio::render_parameters parameters = {
            .in_render_type = audio::render_type::normal,
            .io_action_flags = &actionFlags,
            .io_time_stamp = &timeStamp,
            .in_bus_number = 0,
            .in_number_frames = 1024,
            .io_data = buffer.audio_buffer_list(),
        };

        io_unit.raw_unit_render(parameters);
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), dispatch_labmda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];
}

@end
