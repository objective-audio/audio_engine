//
//  yas_audio_frame_enumerator_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_frame_enumerator_tests : XCTestCase

@end

@implementation yas_audio_frame_enumerator_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadFrameEnumeratorNonInterleaved
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio::format(48000.0, channels);
    yas::audio_pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    yas::test::fill_test_values_to_buffer(buffer);

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *pointer_frame = enumerator.frame();
    const UInt32 *pointer_channel = enumerator.channel();

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointer_frame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointer_channel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, 0, channel));
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

- (void)testReadFrameEnumeratorInterleavedUseMacro
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 3;

    auto format = yas::audio::format(48000, channels, yas::pcm_format::float32, true);
    yas::audio_pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.stride(), channels);

    yas::test::fill_test_values_to_buffer(buffer);

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *pointer_frame = enumerator.frame();
    const UInt32 *pointer_channel = enumerator.channel();

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointer_frame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointer_channel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, channel, 0));
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

- (void)testReadFrameEnumeratorUseFunction
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 3;

    auto format = yas::audio::format(48000, channels, yas::pcm_format::float32, true);
    yas::audio_pcm_buffer data(format, frame_length);

    XCTAssertEqual(format.stride(), channels);

    yas::test::fill_test_values_to_buffer(data);

    yas::audio::frame_enumerator enumerator(data);
    XCTAssertEqual(enumerator.frame_length(), frame_length);
    XCTAssertEqual(enumerator.channel_count(), channels);

    auto pointer = enumerator.pointer();
    const UInt32 *pointer_frame = enumerator.frame();
    const UInt32 *pointer_channel = enumerator.channel();

    for (NSInteger i = 0; i < 2; i++) {
        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*pointer_frame, frame);
            UInt32 channel = 0;
            while (pointer->v) {
                XCTAssertEqual(*pointer_channel, channel);
                XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, channel, 0));
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

- (void)testReadFrameEnumeratorByMove
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio::format(48000, channels);
    yas::audio_pcm_buffer buffer(format, frame_length);

    yas::test::fill_test_values_to_buffer(buffer);

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *pointer_frame = enumerator.frame();
    const UInt32 *pointer_channel = enumerator.channel();

    NSUInteger frame = 0;
    NSUInteger channel = 0;
    while (pointer->v) {
        XCTAssertEqual(frame, *pointer_frame);
        XCTAssertEqual(channel, *pointer_channel);
        XCTAssertEqual(*pointer->f32, yas::test::test_value((UInt32)*pointer_frame, 0, (UInt32)*pointer_channel));

        ++enumerator;  // enumerator.move();

        ++channel;
        if (channel == channels) {
            channel = 0;
            ++frame;
        }
    }

    XCTAssertEqual(frame, frame_length);
}

- (void)testWriteFrameEnumerator
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio::format(48000, channels);
    yas::audio_pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    yas::audio::frame_enumerator mutable_enumerator(buffer);
    const auto *mutable_pointer = mutable_enumerator.pointer();
    const UInt32 *mutable_pointer_frame = mutable_enumerator.frame();
    const UInt32 *mutable_pointer_channel = mutable_enumerator.channel();

    NSUInteger frame = 0;
    while (mutable_pointer->v) {
        XCTAssertEqual(*mutable_pointer_frame, frame);
        UInt32 channel = 0;
        while (mutable_pointer->v) {
            XCTAssertEqual(*mutable_pointer_channel, channel);
            *mutable_pointer->f32 =
                (Float32)yas::test::test_value((UInt32)*mutable_pointer_frame, 0, (UInt32)*mutable_pointer_channel);
            yas_audio_frame_enumerator_move_channel(mutable_enumerator);
            ++channel;
        }
        yas_audio_frame_enumerator_move_frame(mutable_enumerator);
        ++frame;
    }
    XCTAssertEqual(frame, frame_length);

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *pointer_frame = enumerator.frame();
    const UInt32 *pointer_channel = enumerator.channel();

    while (pointer->v) {
        XCTAssertEqual(*pointer->f32,
                       (Float32)yas::test::test_value((UInt32)*pointer_frame, 0, (UInt32)*pointer_channel));
        yas_audio_frame_enumerator_move(enumerator);
    }

    XCTAssertEqual(*pointer_frame, frame_length);
    XCTAssertEqual(*pointer_channel, channels);
}

- (void)testSetFramePosition
{
    const UInt32 frame_length = 16;

    auto format = yas::audio::format(48000, 1);
    yas::audio_pcm_buffer buffer(format, frame_length);

    auto bufferPointer = buffer.flex_ptr_at_index(0);
    for (UInt32 frame = 0; frame < frame_length; ++frame) {
        bufferPointer.f32[frame] = yas::test::test_value(frame, 0, 0);
    }

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *pointer_frame = enumerator.frame();

    XCTAssertEqual(*pointer_frame, 0);
    XCTAssertEqual(*pointer->f32, yas::test::test_value(0, 0, 0));

    enumerator.set_frame_position(3);
    XCTAssertEqual(*pointer_frame, 3);
    XCTAssertEqual(*pointer->f32, yas::test::test_value(3, 0, 0));

    while (pointer->v) {
        yas_audio_frame_enumerator_move_channel(enumerator);
    }

    enumerator.set_frame_position(5);
    XCTAssertFalse(pointer->v);

    enumerator.set_channel_position(0);
    XCTAssertEqual(*pointer->f32, yas::test::test_value(5, 0, 0));

    XCTAssertThrows(enumerator.set_frame_position(16));
    XCTAssertThrows(enumerator.set_frame_position(100));
}

- (void)testSetChannelPosition
{
    const UInt32 channels = 4;

    auto format = yas::audio::format(48000, channels, yas::pcm_format::float32, true);
    yas::audio_pcm_buffer buffer(format, 1);

    auto bufferPointer = buffer.flex_ptr_at_index(0);
    for (UInt32 ch_idx = 0; ch_idx < channels; ch_idx++) {
        bufferPointer.f32[ch_idx] = yas::test::test_value(0, ch_idx, 0);
    }

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *pointer_channel = enumerator.channel();

    XCTAssertEqual(*pointer_channel, 0);
    XCTAssertEqual(*pointer->f32, yas::test::test_value(0, 0, 0));

    enumerator.set_channel_position(2);
    XCTAssertEqual(*pointer_channel, 2);
    XCTAssertEqual(*pointer->f32, yas::test::test_value(0, 2, 0));

    XCTAssertThrows(enumerator.set_channel_position(4));
    XCTAssertThrows(enumerator.set_channel_position(100));
}

- (void)testReadFrameEnumeratorEachPCMFormat
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    for (UInt32 i = static_cast<UInt32>(yas::pcm_format::float32); i <= static_cast<UInt32>(yas::pcm_format::fixed824);
         ++i) {
        auto pcmFormat = static_cast<yas::pcm_format>(i);
        auto format = yas::audio::format(48000.0, channels, pcmFormat, false);
        yas::audio_pcm_buffer buffer(format, frame_length);

        yas::test::fill_test_values_to_buffer(buffer);

        yas::audio::frame_enumerator enumerator(buffer);
        auto pointer = enumerator.pointer();
        const UInt32 *frame = enumerator.frame();
        const UInt32 *channel = enumerator.channel();

        while (pointer->v) {
            while (pointer->v) {
                UInt32 test_value =
                    (Float64)yas::test::test_value(static_cast<UInt32>(*frame), 0, static_cast<UInt32>(*channel));
                switch (pcmFormat) {
                    case yas::pcm_format::float32:
                        XCTAssertEqual(*pointer->f32, static_cast<Float32>(test_value));
                        break;
                    case yas::pcm_format::float64:
                        XCTAssertEqual(*pointer->f64, static_cast<Float64>(test_value));
                        break;
                    case yas::pcm_format::int16:
                        XCTAssertEqual(*pointer->i16, static_cast<SInt16>(test_value));
                        break;
                    case yas::pcm_format::fixed824:
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

- (void)testStop
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;
    const NSUInteger stopFrame = 8;
    const NSUInteger stopChannel = 2;

    auto format = yas::audio::format(48000.0, channels, yas::pcm_format::float32, true);
    yas::audio_pcm_buffer buffer(format, frame_length);

    yas::audio::frame_enumerator enumerator(buffer);
    auto pointer = enumerator.pointer();
    const UInt32 *frame = enumerator.frame();
    const UInt32 *channel = enumerator.channel();

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
