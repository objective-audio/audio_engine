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
    auto format = audio::format(48000.0, 2);
    audio::pcm_buffer pcm_buffer(format, 4);

    XCTAssertTrue(format == pcm_buffer.format());
    XCTAssert(pcm_buffer.flex_ptr_at_index(0).v);
    XCTAssert(pcm_buffer.flex_ptr_at_index(1).v);
    XCTAssertThrows(pcm_buffer.flex_ptr_at_index(2));
}

- (void)test_create_float32_interleaved_1ch_buffer {
    audio::pcm_buffer pcm_buffer(audio::format(48000.0, 1, audio::pcm_format::float32, true), 4);

    XCTAssert(pcm_buffer.flex_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer.flex_ptr_at_index(1));
}

- (void)testCreateFloat64NonInterleaved2chBuffer {
    audio::pcm_buffer pcm_buffer(audio::format(48000.0, 2, audio::pcm_format::float64, false), 4);

    XCTAssert(pcm_buffer.flex_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer.flex_ptr_at_index(2));
}

- (void)test_create_int32_interleaved_3ch_buffer {
    audio::pcm_buffer pcm_buffer(audio::format(48000.0, 3, audio::pcm_format::fixed824, true), 4);

    XCTAssert(pcm_buffer.flex_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer.flex_ptr_at_index(3));
}

- (void)test_create_int16_interleaved_4ch_buffer {
    audio::pcm_buffer pcm_buffer(audio::format(48000.0, 4, audio::pcm_format::int16, false), 4);

    XCTAssert(pcm_buffer.flex_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer.flex_ptr_at_index(4));
}

- (void)test_set_frame_length {
    const uint32_t frame_capacity = 4;

    audio::pcm_buffer pcm_buffer(audio::format(48000.0, 1), frame_capacity);
    const auto &format = pcm_buffer.format();

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
        const uint32_t frame_length = 4;

        auto format = audio::format(48000.0, 2, audio::pcm_format::float32, interleaved);
        audio::pcm_buffer buffer(format, frame_length);

        test::fill_test_values_to_buffer(buffer);

        XCTAssertTrue(test::is_filled_buffer(buffer));

        buffer.reset();

        XCTAssertTrue(test::is_cleared_buffer(buffer));

        test::fill_test_values_to_buffer(buffer);

        buffer.clear(1, 2);

        const uint32_t buffer_count = buffer.format().buffer_count();
        const uint32_t stride = buffer.format().stride();

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
        const uint32_t frame_length = 4;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            const auto pcm_format = static_cast<audio::pcm_format>(i);
            auto format = audio::format(48000.0, 2, pcm_format, interleaved);

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
    const double sample_rate = 48000;
    const uint32_t frame_length = 4;
    const uint32_t channels = 3;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        const auto pcm_format = static_cast<audio::pcm_format>(i);
        auto from_format = audio::format(sample_rate, channels, pcm_format, true);
        auto to_format = audio::format(sample_rate, channels, pcm_format, false);
        audio::pcm_buffer from_buffer(from_format, frame_length);
        audio::pcm_buffer to_buffer(to_format, frame_length);

        test::fill_test_values_to_buffer(from_buffer);

        XCTAssertTrue(to_buffer.copy_from(from_buffer));
        XCTAssertTrue(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)test_copy_data_different_frame_length {
    const double sample_rate = 48000;
    const uint32_t channels = 1;
    const uint32_t from_frame_length = 4;
    const uint32_t to_frame_length = 2;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        const auto pcm_format = static_cast<audio::pcm_format>(i);
        auto format = audio::format(sample_rate, channels, pcm_format, true);
        audio::pcm_buffer from_buffer(format, from_frame_length);
        audio::pcm_buffer to_buffer(format, to_frame_length);

        test::fill_test_values_to_buffer(from_buffer);

        XCTAssertFalse(to_buffer.copy_from(from_buffer, 0, 0, from_frame_length));
        XCTAssertTrue(to_buffer.copy_from(from_buffer, 0, 0, to_frame_length));
        XCTAssertFalse(test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)test_copy_data_start_frame {
    auto test = [self](bool interleaved) {
        const double sample_rate = 48000;
        const uint32_t from_frame_length = 4;
        const uint32_t to_frame_length = 8;
        const uint32_t from_start_frame = 2;
        const uint32_t to_start_frame = 4;
        const uint32_t channels = 2;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            const auto pcm_format = static_cast<audio::pcm_format>(i);
            auto format = audio::format(sample_rate, channels, pcm_format, interleaved);

            audio::pcm_buffer from_buffer(format, from_frame_length);
            audio::pcm_buffer to_buffer(format, to_frame_length);

            test::fill_test_values_to_buffer(from_buffer);

            const uint32_t length = 2;
            XCTAssertTrue(to_buffer.copy_from(from_buffer, from_start_frame, to_start_frame, length));

            for (uint32_t ch_idx = 0; ch_idx < channels; ch_idx++) {
                for (uint32_t i = 0; i < length; i++) {
                    auto from_ptr = test::data_ptr_from_buffer(from_buffer, ch_idx, from_start_frame + i);
                    auto to_ptr = test::data_ptr_from_buffer(to_buffer, ch_idx, to_start_frame + i);
                    XCTAssertEqual(memcmp(from_ptr.v, to_ptr.v, format.sample_byte_count()), 0);
                    BOOL is_from_not_zero = NO;
                    BOOL is_to_not_zero = NO;
                    for (uint32_t j = 0; j < format.sample_byte_count(); j++) {
                        if (from_ptr.u8[j] != 0) {
                            is_from_not_zero = YES;
                        }
                        if (to_ptr.u8[j] != 0) {
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
        const double sample_rate = 48000.0;
        const uint32_t frame_length = 4;
        const uint32_t channels = 2;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            const auto pcm_format = static_cast<audio::pcm_format>(i);
            auto format = audio::format(sample_rate, channels, pcm_format, interleaved);

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
        const double sample_rate = 48000.0;
        const uint32_t frame_length = 4;
        const uint32_t channels = 2;

        for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
             ++i) {
            auto pcm_format = static_cast<audio::pcm_format>(i);
            auto from_format = audio::format(sample_rate, channels, pcm_format, interleaved);
            auto to_format = audio::format(sample_rate, channels, pcm_format, !interleaved);

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
    const double sample_rate = 48000.0;
    const uint32_t frame_length = 4;
    const uint32_t channels = 2;
    const auto from_pcm_format = audio::pcm_format::float32;
    const auto to_pcm_format = audio::pcm_format::fixed824;

    auto from_format = audio::format(sample_rate, channels, from_pcm_format, false);
    auto to_format = audio::format(sample_rate, channels, to_pcm_format, true);

    audio::pcm_buffer from_buffer(from_format, frame_length);
    audio::pcm_buffer to_buffer(to_format, frame_length);

    XCTAssertFalse(to_buffer.copy_from(from_buffer));
}

- (void)test_copy_data_flexibly_from_abl_same_format {
    const double sample_rate = 48000.0;
    const uint32_t frame_length = 4;
    const uint32_t channels = 2;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        auto pcm_format = static_cast<audio::pcm_format>(i);
        auto interleaved_format = audio::format(sample_rate, channels, pcm_format, true);
        auto non_interleaved_format = audio::format(sample_rate, channels, pcm_format, false);
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
    const double sample_rate = 48000.0;
    const uint32_t frame_length = 4;
    const uint32_t channels = 2;

    for (auto i = static_cast<int>(audio::pcm_format::float32); i <= static_cast<int>(audio::pcm_format::fixed824);
         ++i) {
        auto pcm_format = static_cast<audio::pcm_format>(i);
        auto interleaved_format = audio::format(sample_rate, channels, pcm_format, true);
        auto non_interleaved_format = audio::format(sample_rate, channels, pcm_format, false);
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

- (void)test_create_buffer_with_channel_map_many_destination {
    const uint32_t frame_length = 4;
    const uint32_t src_ch_count = 2;
    const uint32_t dst_ch_count = 4;
    const uint32_t sample_rate = 48000;
    const audio::channel_map_t channel_map{3, 0};

    const auto dst_format = audio::format(sample_rate, dst_ch_count);
    audio::pcm_buffer dst_buffer(dst_format, frame_length);
    test::fill_test_values_to_buffer(dst_buffer);

    const auto src_format = audio::format(sample_rate, src_ch_count);
    const audio::pcm_buffer src_buffer(src_format, dst_buffer, channel_map);

    [self assert_buffer_with_channel_map:channel_map
                           source_buffer:src_buffer
                      destination_buffer:dst_buffer
                            frame_length:frame_length];
}

- (void)test_create_buffer_with_channel_map_many_source {
    const uint32_t frame_length = 4;
    const uint32_t src_ch_count = 4;
    const uint32_t dst_ch_count = 2;
    const uint32_t sample_rate = 48000;
    const audio::channel_map_t channel_map{1, static_cast<uint32_t>(-1), static_cast<uint32_t>(-1), 0};

    const auto dst_format = audio::format(sample_rate, dst_ch_count);
    audio::pcm_buffer dst_buffer(dst_format, frame_length);
    test::fill_test_values_to_buffer(dst_buffer);

    const auto src_format = audio::format(sample_rate, src_ch_count);
    const audio::pcm_buffer src_buffer(src_format, dst_buffer, channel_map);

    [self assert_buffer_with_channel_map:channel_map
                           source_buffer:src_buffer
                      destination_buffer:dst_buffer
                            frame_length:frame_length];
}

- (void)test_allocate_abl_interleaved {
    const uint32_t ch_idx = 2;
    const uint32_t size = 4;

    const auto pair = audio::allocate_audio_buffer_list(1, ch_idx, size);
    const audio::abl_uptr &abl = pair.first;

    XCTAssertEqual(abl->mNumberBuffers, 1);
    XCTAssertEqual(abl->mBuffers[0].mNumberChannels, ch_idx);
    XCTAssertEqual(abl->mBuffers[0].mDataByteSize, size);
    XCTAssertTrue(abl->mBuffers[0].mData != nullptr);
}

- (void)test_allocate_abl_deinterleaved {
    const uint32_t buf = 2;
    const uint32_t size = 4;

    const auto pair = audio::allocate_audio_buffer_list(buf, 1, size);
    const audio::abl_uptr &abl = pair.first;

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

    const auto pair1 = audio::allocate_audio_buffer_list(buf, ch_idx, 0);
    const audio::abl_uptr &abl1 = pair1.first;

    XCTAssertTrue(abl1 != nullptr);
    for (uint32_t i = 0; i < buf; i++) {
        XCTAssertEqual(abl1->mBuffers[i].mNumberChannels, ch_idx);
        XCTAssertEqual(abl1->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl1->mBuffers[i].mData == nullptr);
    }

    const auto pair2 = audio::allocate_audio_buffer_list(buf, ch_idx);
    const audio::abl_uptr &abl2 = pair2.first;

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

    std::vector<UInt8> buffer1{0};
    std::vector<UInt8> buffer2{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer1.data();
    abl1->mBuffers[1].mData = abl2->mBuffers[1].mData = buffer2.data();

    XCTAssertTrue(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_is_equal_abl_structure_different_buffer_false {
    auto pair1 = audio::allocate_audio_buffer_list(1, 1);
    auto pair2 = audio::allocate_audio_buffer_list(1, 1);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer1{0};
    std::vector<UInt8> buffer2{0};

    abl1->mBuffers[0].mData = buffer1.data();
    abl2->mBuffers[0].mData = buffer2.data();

    XCTAssertFalse(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_is_equal_abl_structure_different_buffers_false {
    auto pair1 = audio::allocate_audio_buffer_list(1, 1);
    auto pair2 = audio::allocate_audio_buffer_list(2, 1);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer.data();

    XCTAssertFalse(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_is_equal_abl_structure_different_channels_false {
    auto pair1 = audio::allocate_audio_buffer_list(1, 1);
    auto pair2 = audio::allocate_audio_buffer_list(1, 2);
    audio::abl_uptr &abl1 = pair1.first;
    audio::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer.data();

    XCTAssertFalse(audio::is_equal_structure(*abl1, *abl2));
}

- (void)test_data_ptr_at_index_f32 {
    audio::pcm_buffer buffer(audio::format(44100.0, 2), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_index<float>(1), abl->mBuffers[1].mData);
}

- (void)test_data_ptr_at_index_f64 {
    audio::pcm_buffer buffer(audio::format(44100.0, 1, audio::pcm_format::float64), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<double>(0), abl->mBuffers[0].mData);
}

- (void)test_data_ptr_at_index_i16 {
    audio::pcm_buffer buffer(audio::format(44100.0, 1, audio::pcm_format::int16), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<int16_t>(0), abl->mBuffers[0].mData);
}

- (void)test_data_ptr_at_index_fixed824 {
    audio::pcm_buffer buffer(audio::format(44100.0, 1, audio::pcm_format::fixed824), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<int32_t>(0), abl->mBuffers[0].mData);
}

- (void)test_const_data_ptr_at_index {
    const audio::pcm_buffer buffer(audio::format(44100.0, 2), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_index<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_index<float>(1), abl->mBuffers[1].mData);
}

- (void)test_data_ptr_at_channel_deinterleaved {
    audio::pcm_buffer buffer(audio::format(44100.0, 2, audio::pcm_format::float32, false), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), abl->mBuffers[1].mData);
}

- (void)test_const_data_ptr_at_channel_deinterleaved {
    const audio::pcm_buffer buffer(audio::format(44100.0, 2, audio::pcm_format::float32, false), 1);
    auto abl = buffer.audio_buffer_list();

    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), abl->mBuffers[1].mData);
}

- (void)test_data_ptr_at_channel_interleaved {
    audio::pcm_buffer buffer(audio::format(44100.0, 2, audio::pcm_format::float32, true), 1);
    auto abl = buffer.audio_buffer_list();

    float *data = static_cast<float *>(abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), data);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), &data[1]);
}

- (void)test_const_data_ptr_at_channel_interleaved {
    const audio::pcm_buffer buffer(audio::format(44100.0, 2, audio::pcm_format::float32, true), 1);
    auto abl = buffer.audio_buffer_list();

    float *data = static_cast<float *>(abl->mBuffers[0].mData);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(0), data);
    XCTAssertEqual(buffer.data_ptr_at_channel<float>(1), &data[1]);
}

- (void)test_copy_error_to_string {
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::invalid_argument) == "invalid_argument");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::invalid_abl) == "invalid_abl");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::invalid_format) == "invalid_format");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::out_of_range) == "out_of_range");
    XCTAssertTrue(to_string(audio::pcm_buffer::copy_error_t::buffer_is_null) == "buffer_is_null");
}

- (void)test_clear {
    audio::pcm_buffer buffer(audio::format(44100.0, 1), 1);
    auto *data = buffer.data_ptr_at_channel<float>(0);
    *data = 1.0f;

    XCTAssertFalse(*data == 0.0f);

    buffer.clear();

    XCTAssertTrue(*data == 0.0f);
}

- (void)test_abl_frame_length {
    audio::format format{44100.0, 1};
    audio::pcm_buffer buffer{format, 4};

    XCTAssertEqual(audio::frame_length(buffer.audio_buffer_list(), format.sample_byte_count()), 4);
}

#pragma mark -

- (void)assert_buffer_with_channel_map:(const audio::channel_map_t &)channel_map
                         source_buffer:(const audio::pcm_buffer &)src_buffer
                    destination_buffer:(const audio::pcm_buffer &)dst_buffer
                          frame_length:(const uint32_t)frame_length {
    if (src_buffer.format().channel_count() != channel_map.size()) {
        XCTAssert(0);
        return;
    }

    uint32_t src_ch_idx = 0;
    for (const auto &dst_ch_idx : channel_map) {
        if (dst_ch_idx != -1) {
            auto dst_ptr = dst_buffer.flex_ptr_at_index(dst_ch_idx);
            auto src_ptr = src_buffer.flex_ptr_at_index(src_ch_idx);
            XCTAssertEqual(dst_ptr.v, src_ptr.v);
            for (uint32_t frame = 0; frame < frame_length; frame++) {
                float test_value = test::test_value(frame, 0, dst_ch_idx);
                XCTAssertEqual(test_value, src_ptr.f32[frame]);
            }
        } else {
            auto src_ptr = src_buffer.flex_ptr_at_index(src_ch_idx);
            XCTAssertTrue(src_ptr.v != nullptr);
        }

        ++src_ch_idx;
    }
}

@end
