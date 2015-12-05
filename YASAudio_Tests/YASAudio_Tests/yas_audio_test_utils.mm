//
//  yas_audio_test_utils.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_test_utils.h"

using namespace yas;

UInt32 yas::test::test_value(const UInt32 frame, const UInt32 ch_idx, const UInt32 buf_idx)
{
    return frame + 1024 * (ch_idx + 1) + 512 * (buf_idx + 1);
}

void yas::test::fill_test_values_to_buffer(const audio::pcm_buffer &buffer)
{
    const auto &format = buffer.format();
    const yas::pcm_format pcmFormat = format.pcm_format();
    const UInt32 buffer_count = format.buffer_count();
    const UInt32 stride = format.stride();

    for (UInt32 buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        flex_ptr pointer = buffer.flex_ptr_at_index(buf_idx);
        for (UInt32 frame = 0; frame < buffer.frame_length(); frame++) {
            for (UInt32 ch_idx = 0; ch_idx < stride; ch_idx++) {
                UInt32 index = frame * stride + ch_idx;
                UInt32 value = test_value(frame, ch_idx, buf_idx);
                switch (pcmFormat) {
                    case yas::pcm_format::float32: {
                        pointer.f32[index] = value;
                    } break;
                    case yas::pcm_format::float64: {
                        pointer.f64[index] = value;
                    } break;
                    case yas::pcm_format::int16: {
                        pointer.i16[index] = value;
                    } break;
                    case yas::pcm_format::fixed824: {
                        pointer.i32[index] = value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

bool yas::test::is_cleared_buffer(const audio::pcm_buffer &buffer)
{
    const AudioBufferList *abl = buffer.audio_buffer_list();

    for (UInt32 buf_idx = 0; buf_idx < abl->mNumberBuffers; buf_idx++) {
        Byte *ptr = (Byte *)abl->mBuffers[buf_idx].mData;
        for (UInt32 frame = 0; frame < abl->mBuffers[buf_idx].mDataByteSize; frame++) {
            if (ptr[frame] != 0) {
                return false;
            }
        }
    }

    return true;
}

bool yas::test::is_filled_buffer(const audio::pcm_buffer &buffer)
{
    __block BOOL isFilled = YES;
    const UInt32 sample_byte_count = buffer.format().sample_byte_count();
    NSData *zeroData = [NSMutableData dataWithLength:sample_byte_count];
    const void *zeroBytes = [zeroData bytes];

    audio::frame_enumerator enumerator(buffer);
    const flex_ptr *pointer = enumerator.pointer();

    while (pointer->v) {
        if (is_equal_data(pointer->v, zeroBytes, sample_byte_count)) {
            isFilled = NO;
            yas_audio_frame_enumerator_stop(enumerator);
        }
        yas_audio_frame_enumerator_move(enumerator);
    }

    return isFilled;
}

bool yas::test::is_equal_buffer_flexibly(const audio::pcm_buffer &buffer1, const audio::pcm_buffer &buffer2)
{
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

    for (UInt32 ch_idx = 0; ch_idx < buffer1.format().channel_count(); ch_idx++) {
        for (UInt32 frame = 0; frame < buffer1.frame_length(); frame++) {
            auto ptr1 = data_ptr_from_buffer(buffer1, ch_idx, frame);
            auto ptr2 = data_ptr_from_buffer(buffer2, ch_idx, frame);
            if (!is_equal_data(ptr1.v, ptr2.v, buffer1.format().sample_byte_count())) {
                return NO;
            }
        }
    }

    return YES;
}

bool test::is_equal(const Float64 val1, const Float64 val2, const Float64 accuracy)
{
    return ((val1 - accuracy) <= val2 && val2 <= (val1 + accuracy));
}

bool test::is_equal_data(const void *const inbuffer1, const void *const inbuffer2, const size_t inSize)
{
    return memcmp(inbuffer1, inbuffer2, inSize) == 0;
}

bool test::is_equal(const AudioTimeStamp *const ts1, const AudioTimeStamp *const ts2)
{
    if (is_equal_data(ts1, ts2, sizeof(AudioTimeStamp))) {
        return true;
    } else {
        return ((ts1->mFlags == ts2->mFlags) && (ts1->mHostTime == ts2->mHostTime) &&
                (ts1->mWordClockTime == ts2->mWordClockTime) && is_equal(ts1->mSampleTime, ts2->mSampleTime, 0.0001) &&
                is_equal(ts1->mRateScalar, ts2->mRateScalar, 0.0001) &&
                is_equal_data(&ts1->mSMPTETime, &ts2->mSMPTETime, sizeof(SMPTETime)));
    }
}

yas::flex_ptr yas::test::data_ptr_from_buffer(const audio::pcm_buffer &buffer, const UInt32 channel, const UInt32 frame)
{
    audio::frame_enumerator enumerator(buffer);
    enumerator.set_frame_position(frame);
    enumerator.set_channel_position(channel);
    return *enumerator.pointer();
}

void yas::test::audio_unit_render_on_sub_thread(audio_unit &unit, yas::audio::format &format, const UInt32 frame_length,
                                                const NSUInteger count, const NSTimeInterval wait)
{
    auto lambda = [unit, format, frame_length, count, wait]() mutable {
        AudioUnitRenderActionFlags action_flags = 0;

        yas::audio::pcm_buffer buffer(format, frame_length);

        for (NSInteger i = 0; i < count; i++) {
            yas::audio_time audio_time(frame_length * i, format.sample_rate());
            AudioTimeStamp timeStamp = audio_time.audio_time_stamp();

            yas::render_parameters parameters = {
                .in_render_type = yas::render_type::normal,
                .io_action_flags = &action_flags,
                .io_time_stamp = &timeStamp,
                .in_bus_number = 0,
                .in_number_frames = frame_length,
                .io_data = buffer.audio_buffer_list(),
            };

            unit.audio_unit_render(parameters);
        }
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), lambda);

    if (wait > 0) {
        [NSThread sleepForTimeInterval:wait];
    }
}

class test::audio_test_node::impl : public yas::audio_node::impl
{
   public:
    UInt32 input_bus_count() const override
    {
        return _input_bus_count;
    }

    UInt32 output_bus_count() const override
    {
        return _output_bus_count;
    }

    UInt32 _input_bus_count;
    UInt32 _output_bus_count;
};

yas::test::audio_test_node::audio_test_node(const UInt32 input_bus_count, const UInt32 output_bus_count)
    : audio_node(std::make_unique<impl>())
{
    set_input_bus_count(input_bus_count);
    set_output_bus_count(output_bus_count);
}

void yas::test::audio_test_node::set_input_bus_count(const UInt32 &count)
{
    impl_ptr<impl>()->_input_bus_count = count;
}

void yas::test::audio_test_node::set_output_bus_count(const UInt32 &count)
{
    impl_ptr<impl>()->_output_bus_count = count;
}
