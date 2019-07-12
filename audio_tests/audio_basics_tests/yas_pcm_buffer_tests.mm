//
//  yas_pcm_buffer_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_pcm_buffer_tests : XCTestCase

@end

@implementation yas_pcm_buffer_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_standard_buffer {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    audio::pcm_buffer pcm_buffer(format, 4);

    XCTAssertTrue(format == pcm_buffer.format());
    XCTAssert(pcm_buffer.data_ptr_at_index<float>(0));
    XCTAssert(pcm_buffer.data_ptr_at_index<float>(1));
    XCTAssertThrows(pcm_buffer.data_ptr_at_index<float>(2));
}

- (void)test_create_float32_interleaved_1ch_buffer {
    audio::pcm_buffer pcm_buffer(audio::format({.sample_rate = 48000.0,
                                                .channel_count = 1,
                                                .pcm_format = audio::pcm_format::float32,
                                                .interleaved = true}),
                                 4);

    XCTAssert(pcm_buffer.data_ptr_at_index<float>(0));
    XCTAssertThrows(pcm_buffer.data_ptr_at_index<float>(1));
}

- (void)test_create_float64_non_interleaved_2ch_buffer {
    audio::pcm_buffer pcm_buffer(audio::format({.sample_rate = 48000.0,
                                                .channel_count = 2,
                                                .pcm_format = audio::pcm_format::float64,
                                                .interleaved = false}),
                                 4);

    XCTAssert(pcm_buffer.data_ptr_at_index<double>(0));
    XCTAssert(pcm_buffer.data_ptr_at_index<double>(1));
    XCTAssertThrows(pcm_buffer.data_ptr_at_index<double>(2));
}

- (void)test_create_int32_interleaved_3ch_buffer {
    audio::pcm_buffer pcm_buffer(audio::format({.sample_rate = 48000.0,
                                                .channel_count = 3,
                                                .pcm_format = audio::pcm_format::fixed824,
                                                .interleaved = true}),
                                 4);

    XCTAssert(pcm_buffer.data_ptr_at_index<int32_t>(0));
    XCTAssertThrows(pcm_buffer.data_ptr_at_index<int32_t>(1));
}

- (void)test_create_int16_non_interleaved_4ch_buffer {
    audio::pcm_buffer pcm_buffer(
        audio::format(
            {.sample_rate = 48000.0, .channel_count = 4, .pcm_format = audio::pcm_format::int16, .interleaved = false}),
        4);

    XCTAssert(pcm_buffer.data_ptr_at_index<int16_t>(0));
    XCTAssert(pcm_buffer.data_ptr_at_index<int16_t>(1));
    XCTAssert(pcm_buffer.data_ptr_at_index<int16_t>(2));
    XCTAssert(pcm_buffer.data_ptr_at_index<int16_t>(3));
    XCTAssertThrows(pcm_buffer.data_ptr_at_index<int16_t>(4));
}

- (void)test_set_frame_length {
    uint32_t const frame_capacity = 4;

    audio::pcm_buffer pcm_buffer(audio::format({.sample_rate = 48000.0, .channel_count = 1}), frame_capacity);
    auto const &format = pcm_buffer.format();

    XCTAssertEqual(pcm_buffer.frame_length(), frame_capacity);
    XCTAssertEqual(pcm_buffer.audio_buffer_list()->mBuffers[0].mDataByteSize,
                   frame_capacity * format.buffer_frame_byte_count());

    pcm_buffer.set_frame_length(2);

    XCTAssertEqual(pcm_buffer.frame_length(), 2);
    XCTAssertEqual(pcm_buffer.audio_buffer_list()->mBuffers[0].mDataByteSize, 2 * format.buffer_frame_byte_count());

    pcm_buffer.set_frame_length(0);

    XCTAssertEqual(pcm_buffer.frame_length(), 0);
    XCTAssertEqual(pcm_buffer.audio_buffer_list()->mBuffers[0].mDataByteSize, 0);

    XCTAssertThrows(pcm_buffer.set_frame_length(5));
    XCTAssertEqual(pcm_buffer.frame_length(), 0);
}

- (void)test_clear_data {
    auto test = [self](bool interleaved) {
        uint32_t const frame_length = 4;

        auto format = audio::format({.sample_rate = 48000.0,
                                     .channel_count = 2,
                                     .pcm_format = audio::pcm_format::float32,
                                     .interleaved = interleaved});
        audio::pcm_buffer buffer(format, frame_length);

        test::fill_test_values_to_buffer(buffer);

        XCTAssertTrue(test::is_filled_buffer(buffer));

        buffer.reset();

        XCTAssertTrue(test::is_cleared_buffer(buffer));

        test::fill_test_values_to_buffer(buffer);

        buffer.clear(1, 2);

        uint32_t const buffer_count = buffer.format().buffer_count();
        uint32_t const stride = buffer.format().stride();

        for (uint32_t buffer_index = 0; buffer_index < buffer_count; buffer_index++) {
            float *ptr = buffer.data_ptr_at_index<float>(buffer_index);
            for (uint32_t frame = 0; frame < buffer.frame_length(); frame++) {
                for (uint32_t ch_idx = 0; ch_idx < stride; ch_idx++) {
                    if (frame == 1 || frame == 2) {
                        XCTAssertEqual(ptr[frame * stride + ch_idx], 0);
                    } else {
                        XCTAssertNotEqual(ptr[frame * stride + ch_idx], 0);
                    }
                }
            }
        }
    };

    test(false);
    test(true);
}

- (void)test_copy_data_interleaved_format_success {
    auto test = [self](bool interleaved) {
        uint32_t const frame_length = 4;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            auto const pcm_format = static_cast<audio::pcm_format>(i);
            auto format = audio::format(
                {.sample_rate = 48000.0, .channel_count = 2, .pcm_format = pcm_format, .interleaved = interleaved});

            audio::pcm_buffer from_buffer(format, frame_length);
            audio::pcm_buffer to_buffer(format, frame_length);

            test::fill_test_values_to_buffer(from_buffer);

            XCTAssertTrue(to_buffer.copy_from(from_buffer));
            XCTAssertTrue(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
        }
    };

    test(false);
    test(true);
}

- (void)test_copy_data_defferent_interleaved_format_success {
    double const sample_rate = 48000;
    uint32_t const frame_length = 4;
    uint32_t const channels = 3;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        auto const pcm_format = static_cast<audio::pcm_format>(i);
        auto from_format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = true});
        auto to_format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = false});
        audio::pcm_buffer from_buffer(from_format, frame_length);
        audio::pcm_buffer to_buffer(to_format, frame_length);

        test::fill_test_values_to_buffer(from_buffer);

        XCTAssertTrue(to_buffer.copy_from(from_buffer));
        XCTAssertTrue(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)test_copy_data_different_frame_length {
    double const sample_rate = 48000;
    uint32_t const channels = 1;
    uint32_t const from_frame_length = 4;
    uint32_t const to_frame_length = 2;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        auto const pcm_format = static_cast<audio::pcm_format>(i);
        auto format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = true});
        audio::pcm_buffer from_buffer(format, from_frame_length);
        audio::pcm_buffer to_buffer(format, to_frame_length);

        test::fill_test_values_to_buffer(from_buffer);

        XCTAssertFalse(to_buffer.copy_from(from_buffer, {.length = from_frame_length}));
        XCTAssertTrue(to_buffer.copy_from(from_buffer, {.length = to_frame_length}));
        XCTAssertFalse(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)test_copy_data_start_frame {
    auto test = [self](bool interleaved) {
        double const sample_rate = 48000;
        uint32_t const from_frame_length = 4;
        uint32_t const to_frame_length = 8;
        uint32_t const from_start_frame = 2;
        uint32_t const to_start_frame = 4;
        uint32_t const channels = 2;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            auto const pcm_format = static_cast<audio::pcm_format>(i);
            auto format = audio::format({.sample_rate = sample_rate,
                                         .channel_count = channels,
                                         .pcm_format = pcm_format,
                                         .interleaved = interleaved});

            audio::pcm_buffer from_buffer(format, from_frame_length);
            audio::pcm_buffer to_buffer(format, to_frame_length);

            test::fill_test_values_to_buffer(from_buffer);

            uint32_t const length = 2;
            XCTAssertTrue(to_buffer.copy_from(
                from_buffer,
                {.from_begin_frame = from_start_frame, .to_begin_frame = to_start_frame, .length = length}));

            for (uint32_t ch_idx = 0; ch_idx < channels; ch_idx++) {
                for (uint32_t i = 0; i < length; i++) {
                    auto const *from_ptr = test::data_ptr_from_buffer(from_buffer, ch_idx, from_start_frame + i);
                    auto const *to_ptr = test::data_ptr_from_buffer(to_buffer, ch_idx, to_start_frame + i);
                    XCTAssertEqual(memcmp(from_ptr, to_ptr, format.sample_byte_count()), 0);
                    BOOL is_from_not_zero = NO;
                    BOOL is_to_not_zero = NO;
                    for (uint32_t j = 0; j < format.sample_byte_count(); j++) {
                        if (from_ptr[j] != 0) {
                            is_from_not_zero = YES;
                        }
                        if (to_ptr[j] != 0) {
                            is_to_not_zero = YES;
                        }
                    }
                    XCTAssertTrue(is_from_not_zero);
                    XCTAssertTrue(is_to_not_zero);
                }
            }
        }
    };

    test(true);
    test(false);
}

- (void)test_copy_data_flexibly_same_format {
    auto test = [self](bool interleaved) {
        double const sample_rate = 48000.0;
        uint32_t const frame_length = 4;
        uint32_t const channels = 2;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            auto const pcm_format = static_cast<audio::pcm_format>(i);
            auto format = audio::format({.sample_rate = sample_rate,
                                         .channel_count = channels,
                                         .pcm_format = pcm_format,
                                         .interleaved = interleaved});

            audio::pcm_buffer from_buffer(format, frame_length);
            audio::pcm_buffer to_buffer(format, frame_length);

            test::fill_test_values_to_buffer(from_buffer);

            XCTAssertNoThrow(to_buffer.copy_from(from_buffer));
            XCTAssertTrue(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
        }
    };

    test(false);
    test(true);
}

- (void)test_copy_data_flexibly_different_format_success {
    auto test = [self](bool interleaved) {
        double const sample_rate = 48000.0;
        uint32_t const frame_length = 4;
        uint32_t const channels = 2;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            auto pcm_format = static_cast<audio::pcm_format>(i);
            auto from_format = audio::format({.sample_rate = sample_rate,
                                              .channel_count = channels,
                                              .pcm_format = pcm_format,
                                              .interleaved = interleaved});
            auto to_format = audio::format({.sample_rate = sample_rate,
                                            .channel_count = channels,
                                            .pcm_format = pcm_format,
                                            .interleaved = !interleaved});

            audio::pcm_buffer to_buffer(from_format, frame_length);
            audio::pcm_buffer from_buffer(to_format, frame_length);

            test::fill_test_values_to_buffer(from_buffer);

            XCTAssertNoThrow(to_buffer.copy_from(from_buffer));
            XCTAssertTrue(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
            XCTAssertEqual(to_buffer.frame_length(), frame_length);
        }
    };

    test(false);
    test(true);
}

- (void)test_copy_data_flexibly_different_pcm_format_failed {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;
    auto const from_pcm_format = audio::pcm_format::float32;
    auto const to_pcm_format = audio::pcm_format::fixed824;

    auto from_format = audio::format(
        {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = from_pcm_format, .interleaved = false});
    auto to_format = audio::format(
        {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = to_pcm_format, .interleaved = true});

    audio::pcm_buffer from_buffer(from_format, frame_length);
    audio::pcm_buffer to_buffer(to_format, frame_length);

    XCTAssertFalse(to_buffer.copy_from(from_buffer));
}

- (void)test_copy_data_flexibly_from_abl_same_format {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        auto pcm_format = static_cast<audio::pcm_format>(i);
        auto interleaved_format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = true});
        auto non_interleaved_format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = false});
        audio::pcm_buffer interleaved_buffer(interleaved_format, frame_length);
        audio::pcm_buffer deinterleaved_buffer(non_interleaved_format, frame_length);

        test::fill_test_values_to_buffer(interleaved_buffer);

        XCTAssertNoThrow(deinterleaved_buffer.copy_from(interleaved_buffer.audio_buffer_list()));
        XCTAssertTrue(test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
        XCTAssertEqual(deinterleaved_buffer.frame_length(), frame_length);

        interleaved_buffer.reset();
        deinterleaved_buffer.reset();

        test::fill_test_values_to_buffer(deinterleaved_buffer);

        XCTAssertNoThrow(interleaved_buffer.copy_from(deinterleaved_buffer.audio_buffer_list()));
        XCTAssertTrue(test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
        XCTAssertEqual(interleaved_buffer.frame_length(), frame_length);
    }
}

- (void)test_copy_data_flexibly_to_abl {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        auto pcm_format = static_cast<audio::pcm_format>(i);
        auto interleaved_format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = true});
        auto non_interleaved_format = audio::format(
            {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = false});
        audio::pcm_buffer interleaved_buffer(interleaved_format, frame_length);
        audio::pcm_buffer deinterleaved_buffer(non_interleaved_format, frame_length);

        test::fill_test_values_to_buffer(interleaved_buffer);

        XCTAssertNoThrow(interleaved_buffer.copy_to(deinterleaved_buffer.audio_buffer_list()));
        XCTAssertTrue(test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));

        interleaved_buffer.reset();
        deinterleaved_buffer.reset();

        test::fill_test_values_to_buffer(deinterleaved_buffer);

        XCTAssertNoThrow(deinterleaved_buffer.copy_to(interleaved_buffer.audio_buffer_list()));
        XCTAssertTrue(test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
    }
}

- (void)test_copy_channel_int16_data_each_interleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format format{{.sample_rate = sample_rate,
                          .channel_count = channels,
                          .pcm_format = audio::pcm_format::int16,
                          .interleaved = true}};
    audio::pcm_buffer src_buffer{format, frame_length};
    audio::pcm_buffer dst_buffer{format, frame_length};

    int16_t *const src_ptr = src_buffer.data_ptr_at_channel<int16_t>(0);
    src_ptr[0] = 10;
    src_ptr[1] = 20;
    src_ptr[2] = 11;
    src_ptr[3] = 21;
    src_ptr[4] = 12;
    src_ptr[5] = 22;
    src_ptr[6] = 13;
    src_ptr[7] = 23;

    auto result_1 = dst_buffer.copy_channel_from(src_buffer, {.from_channel = 0, .to_channel = 1});
    XCTAssertTrue(result_1);

    int16_t const *const dst_ptr = dst_buffer.data_ptr_at_channel<int16_t>(0);
    XCTAssertEqual(dst_ptr[0], 0);
    XCTAssertEqual(dst_ptr[1], 10);
    XCTAssertEqual(dst_ptr[2], 0);
    XCTAssertEqual(dst_ptr[3], 11);
    XCTAssertEqual(dst_ptr[4], 0);
    XCTAssertEqual(dst_ptr[5], 12);
    XCTAssertEqual(dst_ptr[6], 0);
    XCTAssertEqual(dst_ptr[7], 13);

    dst_buffer.clear();
    auto result_2 = dst_buffer.copy_channel_from(src_buffer, {.from_channel = 1, .to_channel = 0});
    XCTAssertTrue(result_2);

    XCTAssertEqual(dst_ptr[0], 20);
    XCTAssertEqual(dst_ptr[1], 0);
    XCTAssertEqual(dst_ptr[2], 21);
    XCTAssertEqual(dst_ptr[3], 0);
    XCTAssertEqual(dst_ptr[4], 22);
    XCTAssertEqual(dst_ptr[5], 0);
    XCTAssertEqual(dst_ptr[6], 23);
    XCTAssertEqual(dst_ptr[7], 0);
}

- (void)test_copy_channel_float32_data_each_deinterleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format format{{.sample_rate = sample_rate,
                          .channel_count = channels,
                          .pcm_format = audio::pcm_format::float32,
                          .interleaved = false}};
    audio::pcm_buffer src_buffer{format, frame_length};
    audio::pcm_buffer dst_buffer{format, frame_length};

    Float32 *const src_ptr_0 = src_buffer.data_ptr_at_channel<Float32>(0);
    Float32 *const src_ptr_1 = src_buffer.data_ptr_at_channel<Float32>(1);
    src_ptr_0[0] = 10;
    src_ptr_0[1] = 11;
    src_ptr_0[2] = 12;
    src_ptr_0[3] = 13;
    src_ptr_1[0] = 20;
    src_ptr_1[1] = 21;
    src_ptr_1[2] = 22;
    src_ptr_1[3] = 23;

    dst_buffer.copy_channel_from(src_buffer, {.from_channel = 0, .to_channel = 1});

    Float32 const *const dst_ptr_0 = dst_buffer.data_ptr_at_channel<Float32>(0);
    Float32 const *const dst_ptr_1 = dst_buffer.data_ptr_at_channel<Float32>(1);

    XCTAssertEqual(dst_ptr_0[0], 0);
    XCTAssertEqual(dst_ptr_0[1], 0);
    XCTAssertEqual(dst_ptr_0[2], 0);
    XCTAssertEqual(dst_ptr_0[3], 0);
    XCTAssertEqual(dst_ptr_1[0], 10);
    XCTAssertEqual(dst_ptr_1[1], 11);
    XCTAssertEqual(dst_ptr_1[2], 12);
    XCTAssertEqual(dst_ptr_1[3], 13);

    dst_buffer.clear();
    dst_buffer.copy_channel_from(src_buffer, {.from_channel = 1, .to_channel = 0});

    XCTAssertEqual(dst_ptr_0[0], 20);
    XCTAssertEqual(dst_ptr_0[1], 21);
    XCTAssertEqual(dst_ptr_0[2], 22);
    XCTAssertEqual(dst_ptr_0[3], 23);
    XCTAssertEqual(dst_ptr_1[0], 0);
    XCTAssertEqual(dst_ptr_1[1], 0);
    XCTAssertEqual(dst_ptr_1[2], 0);
    XCTAssertEqual(dst_ptr_1[3], 0);
}

- (void)test_copy_channel_fixed824_data_interleaved_to_deinterleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format src_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::fixed824,
                              .interleaved = true}};
    audio::format dst_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::fixed824,
                              .interleaved = false}};
    audio::pcm_buffer src_buffer{src_format, frame_length};
    audio::pcm_buffer dst_buffer{dst_format, frame_length};

    int32_t *const src_ptr = src_buffer.data_ptr_at_channel<int32_t>(0);
    src_ptr[0] = 10;
    src_ptr[1] = 20;
    src_ptr[2] = 11;
    src_ptr[3] = 21;
    src_ptr[4] = 12;
    src_ptr[5] = 22;
    src_ptr[6] = 13;
    src_ptr[7] = 23;

    dst_buffer.copy_channel_from(src_buffer, {.from_channel = 0, .to_channel = 1});

    int32_t const *const dst_ptr_0 = dst_buffer.data_ptr_at_channel<int32_t>(0);
    int32_t const *const dst_ptr_1 = dst_buffer.data_ptr_at_channel<int32_t>(1);

    XCTAssertEqual(dst_ptr_0[0], 0);
    XCTAssertEqual(dst_ptr_0[1], 0);
    XCTAssertEqual(dst_ptr_0[2], 0);
    XCTAssertEqual(dst_ptr_0[3], 0);
    XCTAssertEqual(dst_ptr_1[0], 10);
    XCTAssertEqual(dst_ptr_1[1], 11);
    XCTAssertEqual(dst_ptr_1[2], 12);
    XCTAssertEqual(dst_ptr_1[3], 13);

    dst_buffer.clear();
    dst_buffer.copy_channel_from(src_buffer, {.from_channel = 1, .to_channel = 0});

    XCTAssertEqual(dst_ptr_0[0], 20);
    XCTAssertEqual(dst_ptr_0[1], 21);
    XCTAssertEqual(dst_ptr_0[2], 22);
    XCTAssertEqual(dst_ptr_0[3], 23);
    XCTAssertEqual(dst_ptr_1[0], 0);
    XCTAssertEqual(dst_ptr_1[1], 0);
    XCTAssertEqual(dst_ptr_1[2], 0);
    XCTAssertEqual(dst_ptr_1[3], 0);
}

- (void)test_copy_channel_float64_data_deinterleaved_to_interleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format src_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::float64,
                              .interleaved = false}};
    audio::format dst_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::float64,
                              .interleaved = true}};
    audio::pcm_buffer src_buffer{src_format, frame_length};
    audio::pcm_buffer dst_buffer{dst_format, frame_length};

    Float64 *const src_ptr_0 = src_buffer.data_ptr_at_channel<Float64>(0);
    Float64 *const src_ptr_1 = src_buffer.data_ptr_at_channel<Float64>(1);
    src_ptr_0[0] = 10;
    src_ptr_0[1] = 11;
    src_ptr_0[2] = 12;
    src_ptr_0[3] = 13;
    src_ptr_1[0] = 20;
    src_ptr_1[1] = 21;
    src_ptr_1[2] = 22;
    src_ptr_1[3] = 23;

    dst_buffer.copy_channel_from(src_buffer, {.from_channel = 0, .to_channel = 1});

    Float64 const *const dst_ptr = dst_buffer.data_ptr_at_channel<Float64>(0);
    XCTAssertEqual(dst_ptr[0], 0);
    XCTAssertEqual(dst_ptr[1], 10);
    XCTAssertEqual(dst_ptr[2], 0);
    XCTAssertEqual(dst_ptr[3], 11);
    XCTAssertEqual(dst_ptr[4], 0);
    XCTAssertEqual(dst_ptr[5], 12);
    XCTAssertEqual(dst_ptr[6], 0);
    XCTAssertEqual(dst_ptr[7], 13);

    dst_buffer.clear();
    dst_buffer.copy_channel_from(src_buffer, {.from_channel = 1, .to_channel = 0});

    XCTAssertEqual(dst_ptr[0], 20);
    XCTAssertEqual(dst_ptr[1], 0);
    XCTAssertEqual(dst_ptr[2], 21);
    XCTAssertEqual(dst_ptr[3], 0);
    XCTAssertEqual(dst_ptr[4], 22);
    XCTAssertEqual(dst_ptr[5], 0);
    XCTAssertEqual(dst_ptr[6], 23);
    XCTAssertEqual(dst_ptr[7], 0);
}

- (void)test_copy_channel_from_begin_frame_diff_each_deinterleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format src_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = false}};
    audio::format dst_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = false}};
    audio::pcm_buffer src_buffer{src_format, frame_length};
    audio::pcm_buffer dst_buffer{dst_format, frame_length};

    int16_t *const src_ptr_0 = src_buffer.data_ptr_at_channel<int16_t>(0);
    src_ptr_0[0] = 10;
    src_ptr_0[1] = 11;
    src_ptr_0[2] = 12;
    src_ptr_0[3] = 13;
    int16_t *const src_ptr_1 = src_buffer.data_ptr_at_channel<int16_t>(1);
    src_ptr_1[0] = 20;
    src_ptr_1[1] = 21;
    src_ptr_1[2] = 22;
    src_ptr_1[3] = 23;

    dst_buffer.clear();

    int16_t const *const dst_ptr_0 = dst_buffer.data_ptr_at_channel<int16_t>(0);
    int16_t const *const dst_ptr_1 = dst_buffer.data_ptr_at_channel<int16_t>(1);

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 0, .to_begin_frame = 1, .to_channel = 1, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr_0[0], 0);
        XCTAssertEqual(dst_ptr_0[1], 0);
        XCTAssertEqual(dst_ptr_0[2], 0);
        XCTAssertEqual(dst_ptr_0[3], 0);
        XCTAssertEqual(dst_ptr_1[0], 0);
        XCTAssertEqual(dst_ptr_1[1], 10);
        XCTAssertEqual(dst_ptr_1[2], 11);
        XCTAssertEqual(dst_ptr_1[3], 0);
    }

    dst_buffer.clear();

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 1, .from_channel = 1, .to_begin_frame = 0, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr_0[0], 21);
        XCTAssertEqual(dst_ptr_0[1], 22);
        XCTAssertEqual(dst_ptr_0[2], 0);
        XCTAssertEqual(dst_ptr_0[3], 0);
        XCTAssertEqual(dst_ptr_1[0], 0);
        XCTAssertEqual(dst_ptr_1[1], 0);
        XCTAssertEqual(dst_ptr_1[2], 0);
        XCTAssertEqual(dst_ptr_1[3], 0);
    }
}

- (void)test_copy_channel_from_begin_frame_diff_each_interleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format src_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = true}};
    audio::format dst_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = true}};
    audio::pcm_buffer src_buffer{src_format, frame_length};
    audio::pcm_buffer dst_buffer{dst_format, frame_length};

    int16_t *const src_ptr = src_buffer.data_ptr_at_channel<int16_t>(0);
    src_ptr[0] = 10;
    src_ptr[1] = 20;
    src_ptr[2] = 11;
    src_ptr[3] = 21;
    src_ptr[4] = 12;
    src_ptr[5] = 22;
    src_ptr[6] = 13;
    src_ptr[7] = 23;

    dst_buffer.clear();

    int16_t const *const dst_ptr = dst_buffer.data_ptr_at_channel<int16_t>(0);

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 0, .to_begin_frame = 1, .to_channel = 1, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr[0], 0);
        XCTAssertEqual(dst_ptr[1], 0);
        XCTAssertEqual(dst_ptr[2], 0);
        XCTAssertEqual(dst_ptr[3], 10);
        XCTAssertEqual(dst_ptr[4], 0);
        XCTAssertEqual(dst_ptr[5], 11);
        XCTAssertEqual(dst_ptr[6], 0);
        XCTAssertEqual(dst_ptr[7], 0);
    }

    dst_buffer.clear();

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 1, .from_channel = 1, .to_begin_frame = 0, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr[0], 21);
        XCTAssertEqual(dst_ptr[1], 0);
        XCTAssertEqual(dst_ptr[2], 22);
        XCTAssertEqual(dst_ptr[3], 0);
        XCTAssertEqual(dst_ptr[4], 0);
        XCTAssertEqual(dst_ptr[5], 0);
        XCTAssertEqual(dst_ptr[6], 0);
        XCTAssertEqual(dst_ptr[7], 0);
    }
}

- (void)test_copy_channel_from_begin_frame_diff_deinterleaved_to_interleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format src_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = false}};
    audio::format dst_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = true}};
    audio::pcm_buffer src_buffer{src_format, frame_length};
    audio::pcm_buffer dst_buffer{dst_format, frame_length};

    int16_t *const src_ptr_0 = src_buffer.data_ptr_at_channel<int16_t>(0);
    src_ptr_0[0] = 10;
    src_ptr_0[1] = 11;
    src_ptr_0[2] = 12;
    src_ptr_0[3] = 13;
    int16_t *const src_ptr_1 = src_buffer.data_ptr_at_channel<int16_t>(1);
    src_ptr_1[0] = 20;
    src_ptr_1[1] = 21;
    src_ptr_1[2] = 22;
    src_ptr_1[3] = 23;

    dst_buffer.clear();

    int16_t const *const dst_ptr = dst_buffer.data_ptr_at_channel<int16_t>(0);

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 0, .to_begin_frame = 1, .to_channel = 1, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr[0], 0);
        XCTAssertEqual(dst_ptr[1], 0);
        XCTAssertEqual(dst_ptr[2], 0);
        XCTAssertEqual(dst_ptr[3], 10);
        XCTAssertEqual(dst_ptr[4], 0);
        XCTAssertEqual(dst_ptr[5], 11);
        XCTAssertEqual(dst_ptr[6], 0);
        XCTAssertEqual(dst_ptr[7], 0);
    }

    dst_buffer.clear();

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 1, .from_channel = 1, .to_begin_frame = 0, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr[0], 21);
        XCTAssertEqual(dst_ptr[1], 0);
        XCTAssertEqual(dst_ptr[2], 22);
        XCTAssertEqual(dst_ptr[3], 0);
        XCTAssertEqual(dst_ptr[4], 0);
        XCTAssertEqual(dst_ptr[5], 0);
        XCTAssertEqual(dst_ptr[6], 0);
        XCTAssertEqual(dst_ptr[7], 0);
    }
}

- (void)test_copy_channel_from_begin_frame_diff_interleaved_to_deinterleaved {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;

    audio::format src_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = true}};
    audio::format dst_format{{.sample_rate = sample_rate,
                              .channel_count = channels,
                              .pcm_format = audio::pcm_format::int16,
                              .interleaved = false}};
    audio::pcm_buffer src_buffer{src_format, frame_length};
    audio::pcm_buffer dst_buffer{dst_format, frame_length};

    int16_t *const src_ptr = src_buffer.data_ptr_at_channel<int16_t>(0);
    src_ptr[0] = 10;
    src_ptr[1] = 20;
    src_ptr[2] = 11;
    src_ptr[3] = 21;
    src_ptr[4] = 12;
    src_ptr[5] = 22;
    src_ptr[6] = 13;
    src_ptr[7] = 23;

    dst_buffer.clear();

    int16_t const *const dst_ptr_0 = dst_buffer.data_ptr_at_channel<int16_t>(0);
    int16_t const *const dst_ptr_1 = dst_buffer.data_ptr_at_channel<int16_t>(1);

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 0, .to_begin_frame = 1, .to_channel = 1, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr_0[0], 0);
        XCTAssertEqual(dst_ptr_0[1], 0);
        XCTAssertEqual(dst_ptr_0[2], 0);
        XCTAssertEqual(dst_ptr_0[3], 0);
        XCTAssertEqual(dst_ptr_1[0], 0);
        XCTAssertEqual(dst_ptr_1[1], 10);
        XCTAssertEqual(dst_ptr_1[2], 11);
        XCTAssertEqual(dst_ptr_1[3], 0);
    }

    dst_buffer.clear();

    {
        auto result = dst_buffer.copy_channel_from(
            src_buffer, {.from_begin_frame = 1, .from_channel = 1, .to_begin_frame = 0, .length = 2});
        XCTAssertTrue(result);

        XCTAssertEqual(dst_ptr_0[0], 21);
        XCTAssertEqual(dst_ptr_0[1], 22);
        XCTAssertEqual(dst_ptr_0[2], 0);
        XCTAssertEqual(dst_ptr_0[3], 0);
        XCTAssertEqual(dst_ptr_1[0], 0);
        XCTAssertEqual(dst_ptr_1[1], 0);
        XCTAssertEqual(dst_ptr_1[2], 0);
        XCTAssertEqual(dst_ptr_1[3], 0);
    }
}

- (void)test_create_buffer_with_channel_map_many_destination {
    uint32_t const frame_length = 4;
    uint32_t const src_ch_count = 2;
    uint32_t const dst_ch_count = 4;
    uint32_t const sample_rate = 48000;
    audio::channel_map_t const channel_map{3, 0};

    auto const dst_format = audio::format({.sample_rate = sample_rate, .channel_count = dst_ch_count});
    audio::pcm_buffer dst_buffer(dst_format, frame_length);
    test::fill_test_values_to_buffer(dst_buffer);

    auto const src_format = audio::format({.sample_rate = sample_rate, .channel_count = src_ch_count});
    audio::pcm_buffer const src_buffer(src_format, dst_buffer, channel_map);

    [self assert_buffer_with_channel_map:channel_map
                           source_buffer:src_buffer
                      destination_buffer:dst_buffer
                            frame_length:frame_length];
}

- (void)test_create_buffer_with_channel_map_many_source {
    uint32_t const frame_length = 4;
    uint32_t const src_ch_count = 4;
    uint32_t const dst_ch_count = 2;
    uint32_t const sample_rate = 48000;
    audio::channel_map_t const channel_map{1, static_cast<uint32_t>(-1), static_cast<uint32_t>(-1), 0};

    auto const dst_format = audio::format({.sample_rate = sample_rate, .channel_count = dst_ch_count});
    audio::pcm_buffer dst_buffer(dst_format, frame_length);
    test::fill_test_values_to_buffer(dst_buffer);

    auto const src_format = audio::format({.sample_rate = sample_rate, .channel_count = src_ch_count});
    audio::pcm_buffer const src_buffer(src_format, dst_buffer, channel_map);

    [self assert_buffer_with_channel_map:channel_map
                           source_buffer:src_buffer
                      destination_buffer:dst_buffer
                            frame_length:frame_length];
}

- (void)test_allocate_abl_interleaved {
    uint32_t const ch_idx = 2;
    uint32_t const size = 4;

    auto const pair = audio::allocate_audio_buffer_list(1, ch_idx, size);
    audio::abl_uptr const &abl = pair.first;

    XCTAssertEqual(abl->mNumberBuffers, 1);
    XCTAssertEqual(abl->mBuffers[0].mNumberChannels, ch_idx);
    XCTAssertEqual(abl->mBuffers[0].mDataByteSize, size);
    XCTAssertTrue(abl->mBuffers[0].mData != nullptr);
}

- (void)test_allocate_abl_deinterleaved {
    uint32_t const buf = 2;
    uint32_t const size = 4;

    auto const pair = audio::allocate_audio_buffer_list(buf, 1, size);
    audio::abl_uptr const &abl = pair.first;

    XCTAssertTrue(abl != nullptr);
    XCTAssertEqual(abl->mNumberBuffers, buf);
    for (uint32_t i = 0; i < buf; i++) {
        XCTAssertEqual(abl->mBuffers[i].mNumberChannels, 1);
        XCTAssertEqual(abl->mBuffers[i].mDataByteSize, size);
        XCTAssertTrue(abl->mBuffers[i].mData != nullptr);
    }
}

- (void)test_allocate_abl_without_data {
    uint32_t buf = 1;
    uint32_t ch_idx = 1;

    auto const pair1 = audio::allocate_audio_buffer_list(buf, ch_idx, 0);
    audio::abl_uptr const &abl1 = pair1.first;

    XCTAssertTrue(abl1 != nullptr);
    for (uint32_t i = 0; i < buf; i++) {
        XCTAssertEqual(abl1->mBuffers[i].mNumberChannels, ch_idx);
        XCTAssertEqual(abl1->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl1->mBuffers[i].mData == nullptr);
    }

    auto const pair2 = audio::allocate_audio_buffer_list(buf, ch_idx);
    audio::abl_uptr const &abl2 = pair2.first;

    XCTAssertTrue(abl2 != nullptr);
    XCTAssertEqual(abl2->mNumberBuffers, buf);
    for (uint32_t i = 0; i < buf; i++) {
        XCTAssertEqual(abl2->mBuffers[i].mNumberChannels, ch_idx);
        XCTAssertEqual(abl2->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl2->mBuffers[i].mData == nullptr);
    }
}

- (void)test_is_equal_abl_structure_true {
    auto pair1 = audio::allocate_audio_buffer_list(2, 2);
    auto pair2 = audio::allocate_audio_buffer_list(2, 2);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<uint8_t> buffer1{0};
    std::vector<uint8_t> buffer2{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer1.data();
    abl1->mBuffers[1].mData = abl2->mBuffers[1].mData = buffer2.data();

    XCTAssertTrue(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_is_equal_abl_structure_different_buffer_false {
    auto pair1 = audio::allocate_audio_buffer_list(1, 1);
    auto pair2 = audio::allocate_audio_buffer_list(1, 1);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<uint8_t> buffer1{0};
    std::vector<uint8_t> buffer2{0};

    abl1->mBuffers[0].mData = buffer1.data();
    abl2->mBuffers[0].mData = buffer2.data();

    XCTAssertFalse(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_is_equal_abl_structure_different_buffers_false {
    auto pair1 = audio::allocate_audio_buffer_list(1, 1);
    auto pair2 = audio::allocate_audio_buffer_list(2, 1);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<uint8_t> buffer{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer.data();

    XCTAssertFalse(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_is_equal_abl_structure_different_channels_false {
    auto pair1 = audio::allocate_audio_buffer_list(1, 1);
    auto pair2 = audio::allocate_audio_buffer_list(1, 2);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<uint8_t> buffer{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer.data();

    XCTAssertFalse(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_data_ptr_at_index_f32 {
    audio::pcm_buffer buffer(audio::format({.sample_rate = 44100.0, .channel_count = 2}), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_index<float>(1), abl->mBuffers[1].mData);
}

- (void)test_data_ptr_at_index_f64 {
    audio::pcm_buffer buffer(
        audio::format({.sample_rate = 44100.0, .channel_count = 1, .pcm_format = audio::pcm_format::float64}), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<double>(0), abl->mBuffers[0].mData);
}

- (void)test_data_ptr_at_index_i16 {
    audio::pcm_buffer buffer(
        audio::format({.sample_rate = 44100.0, .channel_count = 1, .pcm_format = audio::pcm_format::int16}), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<int16_t>(0), abl->mBuffers[0].mData);
}

- (void)test_data_ptr_at_index_fixed824 {
    audio::pcm_buffer buffer(
        audio::format({.sample_rate = 44100.0, .channel_count = 1, .pcm_format = audio::pcm_format::fixed824}), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<int32_t>(0), abl->mBuffers[0].mData);
}

- (void)test_const_data_ptr_at_index {
    audio::pcm_buffer const buffer(audio::format({.sample_rate = 44100.0, .channel_count = 2}), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_index<float>(1), abl->mBuffers[1].mData);
}

- (void)test_data_ptr_at_channel_deinterleaved {
    audio::pcm_buffer buffer(audio::format({.sample_rate = 44100.0,
                                            .channel_count = 2,
                                            .pcm_format = audio::pcm_format::float32,
                                            .interleaved = false}),
                             1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), abl->mBuffers[1].mData);
}

- (void)test_const_data_ptr_at_channel_deinterleaved {
    audio::pcm_buffer const buffer(audio::format({.sample_rate = 44100.0,
                                                  .channel_count = 2,
                                                  .pcm_format = audio::pcm_format::float32,
                                                  .interleaved = false}),
                                   1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), abl->mBuffers[1].mData);
}

- (void)test_data_ptr_at_channel_interleaved {
    audio::pcm_buffer buffer(audio::format({.sample_rate = 44100.0,
                                            .channel_count = 2,
                                            .pcm_format = audio::pcm_format::float32,
                                            .interleaved = true}),
                             1);
    auto abl = buffer.audio_buffer_list();

    float *data = static_cast<float *>(abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), data);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), &data[1]);
}

- (void)test_const_data_ptr_at_channel_interleaved {
    audio::pcm_buffer const buffer(audio::format({.sample_rate = 44100.0,
                                                  .channel_count = 2,
                                                  .pcm_format = audio::pcm_format::float32,
                                                  .interleaved = true}),
                                   1);
    auto abl = buffer.audio_buffer_list();

    float *data = static_cast<float *>(abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), data);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), &data[1]);
}

- (void)test_copy_error_to_string {
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::invalid_argument) == "invalid_argument");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::invalid_abl) == "invalid_abl");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::invalid_format) == "invalid_format");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::out_of_range_frame) == "out_of_range_frame");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::out_of_range_channel) == "out_of_range_channel");
}

- (void)test_copy_error_ostream {
    auto const errors = {audio::pcm_buffer::copy_error_t::invalid_argument,
                         audio::pcm_buffer::copy_error_t::invalid_abl, audio::pcm_buffer::copy_error_t::invalid_format,
                         audio::pcm_buffer::copy_error_t::out_of_range_frame,
                         audio::pcm_buffer::copy_error_t::out_of_range_channel};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

- (void)test_clear {
    audio::pcm_buffer buffer(audio::format({.sample_rate = 44100.0, .channel_count = 1}), 1);
    auto *data = buffer.data_ptr_at_channel<float>(0);
    *data = 1.0f;

    XCTAssertFalse(*data == 0.0f);

    buffer.clear();

    XCTAssertTrue(*data == 0.0f);
}

- (void)test_abl_frame_length {
    audio::format format{{.sample_rate = 44100.0, .channel_count = 1}};
    audio::pcm_buffer buffer{format, 4};

    XCTAssertEqual(audio::frame_length(buffer.audio_buffer_list(), format.sample_byte_count()), 4);
}

- (void)test_copy_deinterleaved_data_to_float_data {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;
    audio::pcm_format const pcm_format = audio::pcm_format::float32;

    std::vector<float> to_vector;
    to_vector.resize(frame_length);

    auto deinterleaved_format = audio::format(
        {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = false});
    audio::pcm_buffer deinterleaved_buffer(deinterleaved_format, frame_length);

    test::fill_test_values_to_buffer(deinterleaved_buffer);

    XCTAssertNoThrow(deinterleaved_buffer.copy_to(to_vector.data(), 1, 0, 0, 0, frame_length));

    XCTAssertTrue(test::is_equal_data(deinterleaved_buffer.data_ptr_at_index<float>(0), to_vector.data(),
                                      frame_length * sizeof(float)));

    XCTAssertNoThrow(deinterleaved_buffer.copy_to(to_vector.data(), 1, 0, 1, 0, frame_length));

    XCTAssertTrue(test::is_equal_data(deinterleaved_buffer.data_ptr_at_index<float>(1), to_vector.data(),
                                      frame_length * sizeof(float)));
}

- (void)test_copy_interleaved_data_to_int32_data {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;
    audio::pcm_format const pcm_format = audio::pcm_format::fixed824;

    std::vector<int32_t> to_vector;
    to_vector.resize(frame_length);

    auto interleaved_format = audio::format(
        {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = true});
    audio::pcm_buffer interleaved_buffer(interleaved_format, frame_length);

    test::fill_test_values_to_buffer(interleaved_buffer);

    XCTAssertNoThrow(interleaved_buffer.copy_to(to_vector.data(), 1, 0, 0, 0, frame_length));

    int32_t *data = interleaved_buffer.data_ptr_at_channel<int32_t>(0);
    for (NSInteger i = 0; i < frame_length; ++i) {
        XCTAssertTrue(test::is_equal(data[i * channels], to_vector.at(i)));
    }

    XCTAssertNoThrow(interleaved_buffer.copy_to(to_vector.data(), 1, 0, 1, 0, frame_length));

    data = interleaved_buffer.data_ptr_at_channel<int32_t>(1);
    for (NSInteger i = 0; i < frame_length; ++i) {
        XCTAssertTrue(test::is_equal(data[i * channels], to_vector.at(i)));
    }
}

- (void)test_copy_deinterleaved_data_from_double_data {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;
    audio::pcm_format const pcm_format = audio::pcm_format::float64;

    std::vector<double> from_vector;
    from_vector.reserve(frame_length);
    for (NSInteger i = 0; i < frame_length; i++) {
        from_vector.push_back(double(i));
    }

    auto deinterleaved_format = audio::format(
        {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = false});
    audio::pcm_buffer deinterleaved_buffer(deinterleaved_format, frame_length);

    XCTAssertNoThrow(deinterleaved_buffer.copy_from(from_vector.data(), 1, 0, 0, 0, frame_length));

    XCTAssertTrue(test::is_equal_data(deinterleaved_buffer.data_ptr_at_index<double>(0), from_vector.data(),
                                      frame_length * sizeof(double)));

    XCTAssertNoThrow(deinterleaved_buffer.copy_from(from_vector.data(), 1, 0, 1, 0, frame_length));

    XCTAssertTrue(test::is_equal_data(deinterleaved_buffer.data_ptr_at_index<double>(1), from_vector.data(),
                                      frame_length * sizeof(double)));
}

- (void)test_copy_interleaved_data_from_int16_data {
    double const sample_rate = 48000.0;
    uint32_t const frame_length = 4;
    uint32_t const channels = 2;
    audio::pcm_format const pcm_format = audio::pcm_format::int16;

    std::vector<int16_t> from_vector;
    from_vector.reserve(frame_length);
    for (int16_t i = 0; i < frame_length; i++) {
        from_vector.push_back(i);
    }

    auto interleaved_format = audio::format(
        {.sample_rate = sample_rate, .channel_count = channels, .pcm_format = pcm_format, .interleaved = true});
    audio::pcm_buffer interleaved_buffer(interleaved_format, frame_length);

    test::fill_test_values_to_buffer(interleaved_buffer);

    XCTAssertNoThrow(interleaved_buffer.copy_from(from_vector.data(), 1, 0, 0, 0, frame_length));

    int16_t *data = interleaved_buffer.data_ptr_at_channel<int16_t>(0);
    for (NSInteger i = 0; i < frame_length; ++i) {
        XCTAssertTrue(test::is_equal(data[i * channels], from_vector.at(i)));
    }

    XCTAssertNoThrow(interleaved_buffer.copy_from(from_vector.data(), 1, 0, 1, 0, frame_length));

    data = interleaved_buffer.data_ptr_at_channel<int16_t>(1);
    for (NSInteger i = 0; i < frame_length; ++i) {
        XCTAssertTrue(test::is_equal(data[i * channels], from_vector.at(i)));
    }
}

#pragma mark -

- (void)assert_buffer_with_channel_map:(audio::channel_map_t const &)channel_map
                         source_buffer:(audio::pcm_buffer const &)src_buffer
                    destination_buffer:(audio::pcm_buffer const &)dst_buffer
                          frame_length:(uint32_t const)frame_length {
    if (src_buffer.format().channel_count() != channel_map.size()) {
        XCTAssert(0);
        return;
    }

    uint32_t src_ch_idx = 0;
    for (auto const &dst_ch_idx : channel_map) {
        if (dst_ch_idx != -1) {
            auto *dst_ptr = dst_buffer.data_ptr_at_index<float>(dst_ch_idx);
            auto *src_ptr = src_buffer.data_ptr_at_index<float>(src_ch_idx);
            XCTAssertEqual(dst_ptr, src_ptr);
            for (uint32_t frame = 0; frame < frame_length; frame++) {
                float test_value = test::test_value(frame, 0, dst_ch_idx);
                XCTAssertEqual(test_value, src_ptr[frame]);
            }
        } else {
            auto *src_ptr = src_buffer.data_ptr_at_index<float>(src_ch_idx);
            XCTAssertTrue(src_ptr != nullptr);
        }

        ++src_ch_idx;
    }
}

@end
