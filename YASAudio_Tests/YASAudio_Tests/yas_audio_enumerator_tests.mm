//
//  yas_audio_enumerator_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio_enumerator.h"
#import "yas_audio_test_utils.h"

@interface yas_audio_enumerator_tests : XCTestCase

@end

@implementation yas_audio_enumerator_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testReadEnumeratorNonInterleavedUseMacro
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio_format::create(48000.0, channels);
    auto data = yas::pcm_buffer::create(format, frame_length);

    XCTAssertEqual(format->buffer_count(), channels);

    yas::test::fill_test_values_to_data(data);

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        yas::audio_enumerator enumerator(data, buffer);
        const yas::audio_pointer *pointer = enumerator.pointer();
        const UInt32 *index = enumerator.index();

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, 0, buffer));
                yas_audio_enumerator_move(enumerator);
                ++frame;
            }
            XCTAssertEqual(frame, frame_length);
            yas_audio_enumerator_reset(enumerator);
        }
    }
}

- (void)testReadEnumeratorNonInterleavedUseFunction
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio_format::create(48000.0, channels);
    auto data = yas::pcm_buffer::create(format, frame_length);

    XCTAssertEqual(format->buffer_count(), channels);

    yas::test::fill_test_values_to_data(data);

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        yas::audio_enumerator enumerator(data, buffer);
        const yas::audio_pointer *pointer = enumerator.pointer();
        const UInt32 *index = enumerator.index();

        for (NSInteger i = 0; i < 2; i++) {
            UInt32 frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, 0, buffer));
                enumerator.move();
                ++frame;
            }
            XCTAssertEqual(frame, frame_length);
            enumerator.reset();
        }
    }
}

- (void)testReadEnumeratorInterleaved
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio_format::create(48000.0, channels, yas::pcm_format::float32, true);
    auto data = yas::pcm_buffer::create(format, frame_length);

    XCTAssertEqual(format->stride(), channels);

    yas::test::fill_test_values_to_data(data);

    for (UInt32 ch = 0; ch < channels; ch++) {
        yas::audio_enumerator enumerator(data, ch);
        const yas::audio_pointer *pointer = enumerator.pointer();
        const UInt32 *index = enumerator.index();

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(frame, *index);
            XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, ch, 0));
            yas_audio_enumerator_move(enumerator);
            ++frame;
        }
    }
}

- (void)testWriteEnumerator
{
    const UInt32 frame_length = 16;
    const UInt32 channels = 4;

    auto format = yas::audio_format::create(48000, channels);
    auto data = yas::pcm_buffer::create(format, frame_length);

    XCTAssertEqual(format->buffer_count(), channels);

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        yas::audio_enumerator enumerator(data, buffer);
        const yas::audio_pointer *pointer = enumerator.pointer();
        const UInt32 *index = enumerator.index();

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            *pointer->f32 = (Float32)yas::test::test_value(frame, 0, buffer);
            yas_audio_enumerator_move(enumerator);
            ++frame;
        }

        XCTAssertEqual(frame, frame_length);
    }

    for (UInt32 buffer = 0; buffer < channels; buffer++) {
        yas::audio_enumerator enumerator(data, buffer);
        const yas::audio_pointer *pointer = enumerator.pointer();
        const UInt32 *index = enumerator.index();

        UInt32 frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(frame, 0, buffer));
            yas_audio_enumerator_move(enumerator);
            ++frame;
        }

        XCTAssertEqual(frame, frame_length);
    }
}

- (void)testSetPosition
{
    const NSUInteger frame_length = 16;

    auto format = yas::audio_format::create(48000.0, 1);
    auto data = yas::pcm_buffer::create(format, frame_length);
    yas::audio_enumerator enumerator(data, 0);

    const UInt32 *index = enumerator.index();
    const yas::audio_pointer *pointer = enumerator.pointer();
    const yas::audio_pointer *mutablePointer = enumerator.pointer();

    XCTAssertEqual(*index, 0);

    while (mutablePointer->v) {
        *mutablePointer->f32 = (Float32)yas::test::test_value((UInt32)*index, 0, 0);
        yas_audio_enumerator_move(enumerator);
    }

    enumerator.set_position(3);
    XCTAssertEqual(*index, 3);
    XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(3, 0, 0));

    enumerator.set_position(0);
    XCTAssertEqual(*index, 0);
    XCTAssertEqual(*pointer->f32, (Float32)yas::test::test_value(0, 0, 0));

    XCTAssertThrows(enumerator.set_position(16));
    XCTAssertThrows(enumerator.set_position(100));
}

- (void)testStop
{
    const NSUInteger frame_length = 16;
    const NSUInteger stopIndex = 8;

    auto format = yas::audio_format::create(48000.0, 1);
    auto data = yas::pcm_buffer::create(format, frame_length);

    yas::audio_enumerator enumerator(data, 0);
    const yas::audio_pointer *pointer = enumerator.pointer();
    const UInt32 *index = enumerator.index();

    NSUInteger frame = 0;
    while (pointer->v) {
        if (stopIndex == *index) {
            enumerator.stop();
        }
        yas_audio_enumerator_move(enumerator);
        ++frame;
    }

    XCTAssertEqual(frame, stopIndex + 1);
}

- (void)testInitFailed
{
    yas::audio_pointer pointer = {NULL};

    XCTAssertThrows(yas::audio_enumerator(pointer, 1, 1));

    SInt16 val = 0;
    pointer.v = &val;

    XCTAssertThrows(yas::audio_enumerator(pointer, 0, 1));
    XCTAssertThrows(yas::audio_enumerator(pointer, 1, 0));
}

@end
