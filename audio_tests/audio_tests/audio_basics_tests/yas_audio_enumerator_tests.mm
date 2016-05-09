//
//  yas_audio_enumerator_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_enumerator_tests : XCTestCase

@end

@implementation yas_audio_enumerator_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testReadEnumeratorNonInterleavedUseMacro {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000.0, channels);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    test::fill_test_values_to_buffer(buffer);

    for (uint32_t buf_idx = 0; buf_idx < channels; buf_idx++) {
        audio::enumerator enumerator(buffer, buf_idx);
        const auto pointer = enumerator.pointer();
        const auto index = enumerator.index();

        for (NSInteger i = 0; i < 2; i++) {
            uint32_t frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)test::test_value(frame, 0, buf_idx));
                yas_audio_enumerator_move(enumerator);
                ++frame;
            }
            XCTAssertEqual(frame, frame_length);
            yas_audio_enumerator_reset(enumerator);
        }
    }
}

- (void)testReadEnumeratorNonInterleavedUseFunction {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000.0, channels);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    test::fill_test_values_to_buffer(buffer);

    for (uint32_t buf_idx = 0; buf_idx < channels; buf_idx++) {
        audio::enumerator enumerator(buffer, buf_idx);
        XCTAssertEqual(enumerator.length(), frame_length);

        const auto pointer = enumerator.pointer();
        const auto index = enumerator.index();

        for (NSInteger i = 0; i < 2; i++) {
            uint32_t frame = 0;
            while (pointer->v) {
                XCTAssertEqual(*index, frame);
                XCTAssertEqual(*pointer->f32, (Float32)test::test_value(frame, 0, buf_idx));
                ++enumerator;  // enumerator.move()
                ++frame;
            }
            XCTAssertEqual(frame, frame_length);
            enumerator.reset();
        }
    }
}

- (void)testReadEnumeratorInterleaved {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000.0, channels, audio::pcm_format::float32, true);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.stride(), channels);

    test::fill_test_values_to_buffer(buffer);

    for (uint32_t ch_idx = 0; ch_idx < channels; ch_idx++) {
        audio::enumerator enumerator(buffer, ch_idx);
        const auto pointer = enumerator.pointer();
        const auto index = enumerator.index();

        uint32_t frame = 0;
        while (pointer->v) {
            XCTAssertEqual(frame, *index);
            XCTAssertEqual(*pointer->f32, (Float32)test::test_value(frame, ch_idx, 0));
            yas_audio_enumerator_move(enumerator);
            ++frame;
        }
    }
}

- (void)testWriteEnumerator {
    const uint32_t frame_length = 16;
    const uint32_t channels = 4;

    auto format = audio::format(48000, channels);
    audio::pcm_buffer buffer(format, frame_length);

    XCTAssertEqual(format.buffer_count(), channels);

    for (uint32_t buf_idx = 0; buf_idx < channels; buf_idx++) {
        audio::enumerator enumerator(buffer, buf_idx);
        const auto pointer = enumerator.pointer();
        const auto index = enumerator.index();

        uint32_t frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            *pointer->f32 = (Float32)test::test_value(frame, 0, buf_idx);
            yas_audio_enumerator_move(enumerator);
            ++frame;
        }

        XCTAssertEqual(frame, frame_length);
    }

    for (uint32_t buf_idx = 0; buf_idx < channels; buf_idx++) {
        audio::enumerator enumerator(buffer, buf_idx);
        const auto pointer = enumerator.pointer();
        const auto index = enumerator.index();

        uint32_t frame = 0;
        while (pointer->v) {
            XCTAssertEqual(*index, frame);
            XCTAssertEqual(*pointer->f32, (Float32)test::test_value(frame, 0, buf_idx));
            yas_audio_enumerator_move(enumerator);
            ++frame;
        }

        XCTAssertEqual(frame, frame_length);
    }
}

- (void)testSetPosition {
    const NSUInteger frame_length = 16;

    auto format = audio::format(48000.0, 1);
    audio::pcm_buffer buffer(format, frame_length);
    audio::enumerator enumerator(buffer, 0);

    const auto pointer = enumerator.pointer();
    const auto index = enumerator.index();

    XCTAssertEqual(*index, 0);

    while (pointer->v) {
        *pointer->f32 = (Float32)test::test_value((uint32_t)*index, 0, 0);
        yas_audio_enumerator_move(enumerator);
    }

    enumerator.set_position(3);
    XCTAssertEqual(*index, 3);
    XCTAssertEqual(*pointer->f32, (Float32)test::test_value(3, 0, 0));

    enumerator.set_position(0);
    XCTAssertEqual(*index, 0);
    XCTAssertEqual(*pointer->f32, (Float32)test::test_value(0, 0, 0));

    XCTAssertThrows(enumerator.set_position(16));
    XCTAssertThrows(enumerator.set_position(100));
}

- (void)testStop {
    const NSUInteger frame_length = 16;
    const NSUInteger stopIndex = 8;

    auto format = audio::format(48000.0, 1);
    audio::pcm_buffer buffer(format, frame_length);

    audio::enumerator enumerator(buffer, 0);
    const auto pointer = enumerator.pointer();
    const auto index = enumerator.index();

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

- (void)testInitFailed {
    flex_ptr pointer(nullptr);

    XCTAssertThrows(audio::enumerator(pointer, 1, 1));

    SInt16 val = 0;
    pointer.v = &val;

    XCTAssertThrows(audio::enumerator(pointer, 0, 1));
    XCTAssertThrows(audio::enumerator(pointer, 1, 0));
}

@end
