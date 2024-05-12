//
//  test_utils.mm
//

#include "test_utils.h"

using namespace yas;
using namespace yas::audio;

namespace yas::test::internal {
template <typename T>
bool is_filled_buffer(pcm_buffer const &buffer) {
    auto each = audio::make_each_data<T>(buffer);
    while (yas_each_data_next(each)) {
        if (yas_each_data_value(each) == 0) {
            return false;
        }
    }
    return true;
}

template <typename T>
T const *data_ptr_from_buffer(pcm_buffer const &buffer, uint32_t const channel, uint32_t const frame) {
    auto each_data = audio::make_each_data<T>(buffer);
    auto each_frame = make_fast_each(frame + 1);
    while (yas_each_next(each_frame)) {
        yas_each_data_next_frame(each_data);
    }
    auto each_ch = make_fast_each(channel + 1);
    while (yas_each_next(each_ch)) {
        yas_each_data_next_ch(each_data);
    }
    return yas_each_data_ptr(each_data);
}
}  // namespace yas::test::internal

uint32_t test::test_value(uint32_t const frame, uint32_t const ch_idx, uint32_t const buf_idx) {
    return frame + 1024 * (ch_idx + 1) + 512 * (buf_idx + 1);
}

void test::fill_test_values_to_buffer(pcm_buffer &buffer) {
    auto const &format = buffer.format();
    audio::pcm_format const pcmFormat = format.pcm_format();
    uint32_t const buffer_count = format.buffer_count();
    uint32_t const stride = format.stride();

    for (uint32_t buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        for (uint32_t frame = 0; frame < buffer.frame_length(); frame++) {
            for (uint32_t ch_idx = 0; ch_idx < stride; ch_idx++) {
                uint32_t index = frame * stride + ch_idx;
                uint32_t value = test_value(frame, ch_idx, buf_idx);
                switch (pcmFormat) {
                    case audio::pcm_format::float32: {
                        auto *ptr = buffer.data_ptr_at_index<float>(buf_idx);
                        ptr[index] = value;
                    } break;
                    case audio::pcm_format::float64: {
                        auto *ptr = buffer.data_ptr_at_index<double>(buf_idx);
                        ptr[index] = value;
                    } break;
                    case audio::pcm_format::int16: {
                        auto *ptr = buffer.data_ptr_at_index<int16_t>(buf_idx);
                        ptr[index] = value;
                    } break;
                    case audio::pcm_format::fixed824: {
                        auto *ptr = buffer.data_ptr_at_index<int32_t>(buf_idx);
                        ptr[index] = value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

bool test::is_cleared_buffer(pcm_buffer const &buffer) {
    AudioBufferList const *abl = buffer.audio_buffer_list();

    for (uint32_t buf_idx = 0; buf_idx < abl->mNumberBuffers; buf_idx++) {
        Byte *ptr = (Byte *)abl->mBuffers[buf_idx].mData;
        for (uint32_t frame = 0; frame < abl->mBuffers[buf_idx].mDataByteSize; frame++) {
            if (ptr[frame] != 0) {
                return false;
            }
        }
    }

    return true;
}

bool test::is_filled_buffer(pcm_buffer const &buffer) {
    switch (buffer.format().pcm_format()) {
        case audio::pcm_format::float32:
            return internal::is_filled_buffer<float>(buffer);
        case audio::pcm_format::float64:
            return internal::is_filled_buffer<double>(buffer);
        case audio::pcm_format::int16:
            return internal::is_filled_buffer<int16_t>(buffer);
        case audio::pcm_format::fixed824:
            return internal::is_filled_buffer<int32_t>(buffer);

        default:
            throw "invalid pcm format.";
    }
}

bool test::is_equal_buffer_flexibly(pcm_buffer const &buffer1, pcm_buffer const &buffer2) {
    if (buffer1.format().channel_count() != buffer2.format().channel_count()) {
        return NO;
    }

    if (buffer1.frame_length() != buffer2.frame_length()) {
        return NO;
    }

    if (buffer1.format().sample_byte_count() != buffer2.format().sample_byte_count()) {
        return NO;
    }

    if (buffer1.format().pcm_format() != buffer2.format().pcm_format()) {
        return NO;
    }

    for (uint32_t ch_idx = 0; ch_idx < buffer1.format().channel_count(); ch_idx++) {
        for (uint32_t frame = 0; frame < buffer1.frame_length(); frame++) {
            auto ptr1 = data_ptr_from_buffer(buffer1, ch_idx, frame);
            auto ptr2 = data_ptr_from_buffer(buffer2, ch_idx, frame);
            if (!is_equal_data(ptr1, ptr2, buffer1.format().sample_byte_count())) {
                return NO;
            }
        }
    }

    return YES;
}

bool test::is_equal(double const val1, double const val2, double const accuracy) {
    return ((val1 - accuracy) <= val2 && val2 <= (val1 + accuracy));
}

bool test::is_equal_data(void const *const inbuffer1, void const *const inbuffer2, std::size_t const inSize) {
    return memcmp(inbuffer1, inbuffer2, inSize) == 0;
}

bool test::is_equal(AudioTimeStamp const *const ts1, AudioTimeStamp const *const ts2) {
    if (is_equal_data(ts1, ts2, sizeof(AudioTimeStamp))) {
        return true;
    } else {
        return ((ts1->mFlags == ts2->mFlags) && (ts1->mHostTime == ts2->mHostTime) &&
                (ts1->mWordClockTime == ts2->mWordClockTime) && is_equal(ts1->mSampleTime, ts2->mSampleTime, 0.0001) &&
                is_equal(ts1->mRateScalar, ts2->mRateScalar, 0.0001) &&
                is_equal_data(&ts1->mSMPTETime, &ts2->mSMPTETime, sizeof(SMPTETime)));
    }
}

uint8_t const *test::data_ptr_from_buffer(pcm_buffer const &buffer, uint32_t const channel, uint32_t const frame) {
    switch (buffer.format().pcm_format()) {
        case audio::pcm_format::float32:
            return (uint8_t const *)internal::data_ptr_from_buffer<float>(buffer, channel, frame);
        case audio::pcm_format::float64:
            return (uint8_t const *)internal::data_ptr_from_buffer<double>(buffer, channel, frame);
        case audio::pcm_format::int16:
            return (uint8_t const *)internal::data_ptr_from_buffer<int16_t>(buffer, channel, frame);
        case audio::pcm_format::fixed824:
            return (uint8_t const *)internal::data_ptr_from_buffer<int32_t>(buffer, channel, frame);

        default:
            throw "invalid pcm format.";
    }
}

test::node_object::node_object(uint32_t const input_bus_count, uint32_t const output_bus_count)
    : node(audio::graph_node::make_shared(
          audio::graph_node_args{.input_bus_count = input_bus_count, .output_bus_count = output_bus_count})) {
}
