//
//  yas_audio_frame_enumerator_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_frame_enumerator_tests : XCTestCase

@end

@implementation yas_audio_frame_enumerator_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testReadFrameEnumeratorNonInterleaved {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000.0, channels);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    test::fill_test_values_to_buffer(buffer);

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *pointer_frame = enumerator.frame();
    const uint32_t *pointer_channel = enumerator.channel();

    for (NSInteger i = 0; i < 2; i++) {
        uint32_t frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointer_frame, frame);
            uint32_t channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointer_channel, channel);
                XCTAssertEqual(*pointer->f32, (float)test::test_value(frame, 0, channel));
                yas_audio_frame_enumerator_move_channel(enumerator);
                ++channel;
            }
            XCTAssertEqual(channel, channels);
            yas_audio_frame_enumerator_move_frame(enumerator);
            ++frame;
        }
        XCTAssertEqual(frame, frame_length);
        yas_audio_frame_enumerator_reset(enumerator);
    }
}

- (void)testReadFrameEnumeratorInterleavedUseMacro {
    const uint32_t frame_length = 16;
    const uint32_t channels = 3;

    auto format = audio::format(48000, channels, audio::pcm_format::float32, true);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.stride(), channels);

    test::fill_test_values_to_buffer(buffer);

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *pointer_frame = enumerator.frame();
    const uint32_t *pointer_channel = enumerator.channel();

    for (NSInteger i = 0; i < 2; i++) {
        uint32_t frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointer_frame, frame);
            uint32_t channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointer_channel, channel);
                XCTAssertEqual(*pointer->f32, (float)test::test_value(frame, channel, 0));
                yas_audio_frame_enumerator_move_channel(enumerator);
                ++channel;
            }
            XCTAssertEqual(channel, channels);
            yas_audio_frame_enumerator_move_frame(enumerator);
            ++frame;
        }
        XCTAssertEqual(frame, frame_length);
        yas_audio_frame_enumerator_reset(enumerator);
    }
}

- (void)testReadFrameEnumeratorUseFunction {
    const uint32_t frame_length = 16;
    const uint32_t channels = 3;

    auto format = audio::format(48000, channels, audio::pcm_format::float32, true);
    audio::pcm_buffer data(format, frame_length);

    XCTAssertEqual(format.stride(), channels);

    test::fill_test_values_to_buffer(data);

    audio::frame_enumerator enumerator(data);
    XCTAssertEqual(enumerator.frame_length(), frame_length);
    XCTAssertEqual(enumerator.channel_count(), channels);

    auto pointer = enumerator.pointer();
    const uint32_t *pointer_frame = enumerator.frame();
    const uint32_t *pointer_channel = enumerator.channel();

    for (NSInteger i = 0; i < 2; i++) {
        uint32_t frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointer_frame, frame);
            uint32_t channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointer_channel, channel);
                XCTAssertEqual(*pointer->f32, (float)test::test_value(frame, channel, 0));
                enumerator.move_channel();
                ++channel;
            }
            XCTAssertEqual(channel, channels);
            enumerator.move_frame();
            ++frame;
        }
        XCTAssertEqual(frame, frame_length);
        enumerator.reset();
    }
}

- (void)testReadFrameEnumeratorByMove {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000, channels);
    audio::pcm_buffer buffer(format, frame_length);

    test::fill_test_values_to_buffer(buffer);

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *pointer_frame = enumerator.frame();
    const uint32_t *pointer_channel = enumerator.channel();

    NSUInteger frame = 0;
    NSUInteger channel = 0;
    while (pointer->v) {
        XCTAssertEqual(frame, *pointer_frame);
        XCTAssertEqual(channel, *pointer_channel);
        XCTAssertEqual(*pointer->f32, test::test_value((uint32_t)*pointer_frame, 0, (uint32_t)*pointer_channel));

        ++enumerator;  // enumerator.move();

        ++channel;
        if (channel == channels) {
            channel = 0;
            ++frame;
        }
    }

    XCTAssertEqual(frame, frame_length);
}

- (void)testWriteFrameEnumerator {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000, channels);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    audio::frame_enumerator mutable_enumerator(buffer);
    const auto *mutable_pointer = mutable_enumerator.pointer();
    const uint32_t *mutable_pointer_frame = mutable_enumerator.frame();
    const uint32_t *mutable_pointer_channel = mutable_enumerator.channel();

    NSUInteger frame = 0;
    while (mutable_pointer->v) {
        XCTAssertEqual(*mutable_pointer_frame, frame);
        uint32_t channel = 0;
        while (mutable_pointer->v) {
            XCTAssertEqual(*mutable_pointer_channel, channel);
            *mutable_pointer->f32 =
                (float)test::test_value((uint32_t)*mutable_pointer_frame, 0, (uint32_t)*mutable_pointer_channel);
            yas_audio_frame_enumerator_move_channel(mutable_enumerator);
            ++channel;
        }
        yas_audio_frame_enumerator_move_frame(mutable_enumerator);
        ++frame;
    }
    XCTAssertEqual(frame, frame_length);

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *pointer_frame = enumerator.frame();
    const uint32_t *pointer_channel = enumerator.channel();

    while (pointer->v) {
        XCTAssertEqual(*pointer->f32, (float)test::test_value((uint32_t)*pointer_frame, 0, (uint32_t)*pointer_channel));
        yas_audio_frame_enumerator_move(enumerator);
    }

    XCTAssertEqual(*pointer_frame, frame_length);
    XCTAssertEqual(*pointer_channel, channels);
}

- (void)testSetFramePosition {
    const uint32_t frame_length = 16;

    auto format = audio::format(48000, 1);
    audio::pcm_buffer buffer(format, frame_length);

    auto bufferPointer = buffer.flex_ptr_at_index(0);
    for (uint32_t frame = 0; frame < frame_length; ++frame) {
        bufferPointer.f32[frame] = test::test_value(frame, 0, 0);
    }

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *pointer_frame = enumerator.frame();

    XCTAssertEqual(*pointer_frame, 0);
    XCTAssertEqual(*pointer->f32, test::test_value(0, 0, 0));

    enumerator.set_frame_position(3);
    XCTAssertEqual(*pointer_frame, 3);
    XCTAssertEqual(*pointer->f32, test::test_value(3, 0, 0));

    while (pointer->v) {
        yas_audio_frame_enumerator_move_channel(enumerator);
    }

    enumerator.set_frame_position(5);
    XCTAssertFalse(pointer->v);

    enumerator.set_channel_position(0);
    XCTAssertEqual(*pointer->f32, test::test_value(5, 0, 0));

    XCTAssertThrows(enumerator.set_frame_position(16));
    XCTAssertThrows(enumerator.set_frame_position(100));
}

- (void)testSetChannelPosition {
    const uint32_t channels = 4;

    auto format = audio::format(48000, channels, audio::pcm_format::float32, true);
    audio::pcm_buffer buffer(format, 1);

    auto bufferPointer = buffer.flex_ptr_at_index(0);
    for (uint32_t ch_idx = 0; ch_idx < channels; ch_idx++) {
        bufferPointer.f32[ch_idx] = test::test_value(0, ch_idx, 0);
    }

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *pointer_channel = enumerator.channel();

    XCTAssertEqual(*pointer_channel, 0);
    XCTAssertEqual(*pointer->f32, test::test_value(0, 0, 0));

    enumerator.set_channel_position(2);
    XCTAssertEqual(*pointer_channel, 2);
    XCTAssertEqual(*pointer->f32, test::test_value(0, 2, 0));

    XCTAssertThrows(enumerator.set_channel_position(4));
    XCTAssertThrows(enumerator.set_channel_position(100));
}

- (void)testReadFrameEnumeratorEachPCMFormat {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    for (uint32_t i = static_cast<uint32_t>(audio::pcm_format::float32);
         i <= static_cast<uint32_t>(audio::pcm_format::fixed824); ++i) {
        auto pcmFormat = static_cast<audio::pcm_format>(i);
        auto format = audio::format(48000.0, channels, pcmFormat, false);
        audio::pcm_buffer buffer(format, frame_length);

        test::fill_test_values_to_buffer(buffer);

        audio::frame_enumerator enumerator(buffer);
        auto pointer = enumerator.pointer();
        const uint32_t *frame = enumerator.frame();
        const uint32_t *channel = enumerator.channel();

        while (pointer->v) {
            while (pointer->v) {
                uint32_t test_value =
                    (double)test::test_value(static_cast<uint32_t>(*frame), 0, static_cast<uint32_t>(*channel));
                switch (pcmFormat) {
                    case audio::pcm_format::float32:
                        XCTAssertEqual(*pointer->f32, static_cast<float>(test_value));
                        break;
                    case audio::pcm_format::float64:
                        XCTAssertEqual(*pointer->f64, static_cast<double>(test_value));
                        break;
                    case audio::pcm_format::int16:
                        XCTAssertEqual(*pointer->i16, static_cast<SInt16>(test_value));
                        break;
                    case audio::pcm_format::fixed824:
                        XCTAssertEqual(*pointer->i32, static_cast<SInt32>(test_value));
                        break;
                    default:
                        XCTAssert(0);
                        break;
                }

                yas_audio_frame_enumerator_move_channel(enumerator);
            }
            XCTAssertEqual(*channel, channels);
            yas_audio_frame_enumerator_move_frame(enumerator);
        }

        XCTAssertEqual(*frame, frame_length);
    }
}

- (void)testStop {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;
    const NSUInteger stopFrame = 8;
    const NSUInteger stopChannel = 2;

    auto format = audio::format(48000.0, channels, audio::pcm_format::float32, true);
    audio::pcm_buffer buffer(format, frame_length);

    audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const uint32_t *frame = enumerator.frame();
    const uint32_t *channel = enumerator.channel();

    NSUInteger fr = 0;
    NSUInteger ch_idx;
    while (pointer->v) {
        ch_idx = 0;
        while (pointer->v) {
            if (*frame == stopFrame && *channel == stopChannel) {
                enumerator.stop();
            }
            yas_audio_frame_enumerator_move_channel(enumerator);
            ch_idx++;
        }
        yas_audio_frame_enumerator_move_frame(enumerator);
        fr++;
    }

    XCTAssertEqual(fr, stopFrame + 1);
    XCTAssertEqual(ch_idx, stopChannel + 1);
}

@end
