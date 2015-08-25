//
//  yas_audio_test_utils.cpp
//  YASAudio_Tests
//
//  Created by Yuki Yasoshima on 2015/05/19.
//
//

#include "yas_audio_test_utils.h"
#include "yas_audio_unit.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_enumerator.h"
#include "yas_audio_time.h"
#import "YASAudioData+Internal.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"

using namespace yas;

UInt32 yas::test::test_value(const UInt32 frame, const UInt32 ch_idx, const UInt32 buf_idx)
{
    return frame + 1024 * (ch_idx + 1) + 512 * (buf_idx + 1);
}

void yas::test::fill_test_values_to_buffer(audio_pcm_buffer_sptr &buffer)
{
    const auto &format = buffer->format();
    const yas::pcm_format pcmFormat = format->pcm_format();
    const UInt32 buffer_count = format->buffer_count();
    const UInt32 stride = format->stride();

    for (UInt32 buf_idx = 0; buf_idx < buffer_count; buf_idx++) {
        flex_pointer pointer = buffer->audio_ptr_at_index(buf_idx);
        for (UInt32 frame = 0; frame < buffer->frame_length(); frame++) {
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

bool yas::test::is_cleard_buffer(audio_pcm_buffer_sptr &buffer)
{
    const AudioBufferList *abl = buffer->audio_buffer_list();

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

bool yas::test::is_filled_buffer(audio_pcm_buffer_sptr &buffer)
{
    __block BOOL isFilled = YES;
    const UInt32 sample_byte_count = buffer->format()->sample_byte_count();
    NSData *zeroData = [NSMutableData dataWithLength:sample_byte_count];
    const void *zeroBytes = [zeroData bytes];

    audio_frame_enumerator enumerator(buffer);
    const flex_pointer *pointer = enumerator.pointer();

    while (pointer->v) {
        if (YASAudioIsEqualData(pointer->v, zeroBytes, sample_byte_count)) {
            isFilled = NO;
            yas_audio_frame_enumerator_stop(enumerator);
        }
        yas_audio_frame_enumerator_move(enumerator);
    }

    return isFilled;
}

bool yas::test::is_equal_buffer_flexibly(audio_pcm_buffer_sptr &data1, audio_pcm_buffer_sptr &data2)
{
    if (data1->format()->channel_count() != data2->format()->channel_count()) {
        return NO;
    }

    if (data1->frame_length() != data2->frame_length()) {
        return NO;
    }

    if (data1->format()->sample_byte_count() != data2->format()->sample_byte_count()) {
        return NO;
    }

    if (data1->format()->pcm_format() != data2->format()->pcm_format()) {
        return NO;
    }

    for (UInt32 ch_idx = 0; ch_idx < data1->format()->channel_count(); ch_idx++) {
        for (UInt32 frame = 0; frame < data1->frame_length(); frame++) {
            auto ptr1 = data_ptr_from_buffer(data1, ch_idx, frame);
            auto ptr2 = data_ptr_from_buffer(data2, ch_idx, frame);
            if (!YASAudioIsEqualData(ptr1.v, ptr2.v, data1->format()->sample_byte_count())) {
                return NO;
            }
        }
    }

    return YES;
}

yas::flex_pointer yas::test::data_ptr_from_buffer(audio_pcm_buffer_sptr &buffer, const UInt32 channel, const UInt32 frame)
{
    audio_frame_enumerator enumerator(buffer);
    enumerator.set_frame_position(frame);
    enumerator.set_channel_position(channel);
    return *enumerator.pointer();
}

void yas::test::audio_unit_render_on_sub_thread(std::shared_ptr<audio_unit> audio_unit, yas::audio_format_sptr format,
                                                const UInt32 frame_length, const NSUInteger count,
                                                const NSTimeInterval wait)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                   [audio_unit, format, frame_length, count, wait]() {
                       AudioUnitRenderActionFlags action_flags = 0;

                       yas::audio_pcm_buffer_sptr buffer = yas::audio_pcm_buffer::create(format, frame_length);

                       for (NSInteger i = 0; i < count; i++) {
                           yas::audio_time audio_time(frame_length * i, format->sample_rate());
                           AudioTimeStamp timeStamp = audio_time.audio_time_stamp();

                           yas::render_parameters parameters = {
                               .in_render_type = yas::render_type::normal,
                               .io_action_flags = &action_flags,
                               .io_time_stamp = &timeStamp,
                               .in_bus_number = 0,
                               .in_number_frames = frame_length,
                               .io_data = buffer->audio_buffer_list(),
                           };

                           audio_unit->audio_unit_render(parameters);
                       }
                   });

    if (wait > 0) {
        [NSThread sleepForTimeInterval:wait];
    }
}

test::audio_test_node_ptr test::audio_test_node::create(const uint32_t input_bus_count, const uint32_t output_bus_count)
{
    auto node = audio_test_node_ptr(new audio_test_node());
    node->_input_bus_count = input_bus_count;
    node->_output_bus_count = output_bus_count;
    return node;
}

uint32_t yas::test::audio_test_node::input_bus_count() const
{
    return _input_bus_count;
}

uint32_t yas::test::audio_test_node::output_bus_count() const
{
    return _output_bus_count;
}
