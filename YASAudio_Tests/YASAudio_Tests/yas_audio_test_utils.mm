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
#include "yas_audio_data.h"
#include "yas_audio_enumerator.h"
#include "yas_audio_time.h"
#import "YASAudioData+Internal.h"
#import "YASAudioFormat.h"
#import "YASAudioUtility.h"
#import "YASMacros.h"

using namespace yas;

UInt32 yas::test::test_value(const UInt32 frame, const UInt32 channel, const UInt32 buffer)
{
    return frame + 1024 * (channel + 1) + 512 * (buffer + 1);
}

void yas::test::fill_test_values_to_data(audio_data_ptr &data)
{
    const auto &format = data->format();
    const yas::pcm_format pcmFormat = format->pcm_format();
    const UInt32 bufferCount = format->buffer_count();
    const UInt32 stride = format->stride();

    for (UInt32 buffer = 0; buffer < bufferCount; buffer++) {
        audio_pointer pointer = data->audio_ptr_at_buffer(buffer);
        for (UInt32 frame = 0; frame < data->frame_length(); frame++) {
            for (UInt32 ch = 0; ch < stride; ch++) {
                UInt32 index = frame * stride + ch;
                UInt32 value = test_value(frame, ch, buffer);
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

bool yas::test::is_cleard_data(audio_data_ptr &data)
{
    const AudioBufferList *abl = data->audio_buffer_list();

    for (UInt32 buffer = 0; buffer < abl->mNumberBuffers; buffer++) {
        Byte *ptr = (Byte *)abl->mBuffers[buffer].mData;
        for (UInt32 frame = 0; frame < abl->mBuffers[buffer].mDataByteSize; frame++) {
            if (ptr[frame] != 0) {
                return false;
            }
        }
    }

    return true;
}

bool yas::test::is_filled_data(audio_data_ptr &data)
{
    __block BOOL isFilled = YES;
    const UInt32 sample_byte_count = data->format()->sample_byte_count();
    NSData *zeroData = [NSMutableData dataWithLength:sample_byte_count];
    const void *zeroBytes = [zeroData bytes];

    audio_frame_enumerator enumerator(data);
    const audio_pointer *pointer = enumerator.pointer();

    while (pointer->v) {
        if (YASAudioIsEqualData(pointer->v, zeroBytes, sample_byte_count)) {
            isFilled = NO;
            yas_audio_frame_enumerator_stop(enumerator);
        }
        yas_audio_frame_enumerator_move(enumerator);
    }

    return isFilled;
}

bool yas::test::is_equal_data_flexibly(audio_data_ptr &data1, audio_data_ptr &data2)
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

    for (UInt32 ch = 0; ch < data1->format()->channel_count(); ch++) {
        for (UInt32 frame = 0; frame < data1->frame_length(); frame++) {
            yas::audio_pointer ptr1 = data_ptr_from_data(data1, ch, frame);
            yas::audio_pointer ptr2 = data_ptr_from_data(data2, ch, frame);
            if (!YASAudioIsEqualData(ptr1.v, ptr2.v, data1->format()->sample_byte_count())) {
                return NO;
            }
        }
    }

    return YES;
}

yas::audio_pointer yas::test::data_ptr_from_data(audio_data_ptr &data, const UInt32 channel, const UInt32 frame)
{
    audio_frame_enumerator enumerator(data);
    enumerator.set_frame_position(frame);
    enumerator.set_channel_position(channel);
    return *enumerator.pointer();
}

void yas::test::audio_unit_render_on_sub_thread(std::shared_ptr<audio_unit> audio_unit, yas::audio_format_ptr format,
                                                const UInt32 frame_length, const NSUInteger count,
                                                const NSTimeInterval wait)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   [audio_unit, format, frame_length, count, wait]() {
                       AudioUnitRenderActionFlags action_flags = 0;

                       yas::audio_data_ptr data = yas::audio_data::create(format, frame_length);

                       for (NSInteger i = 0; i < count; i++) {
                           yas::audio_time audio_time(frame_length * i, format->sample_rate());
                           AudioTimeStamp timeStamp = audio_time.audio_time_stamp();

                           yas::render_parameters parameters = {
                               .in_render_type = yas::render_type::normal,
                               .io_action_flags = &action_flags,
                               .io_time_stamp = &timeStamp,
                               .in_bus_number = 0,
                               .in_number_frames = frame_length,
                               .io_data = data->audio_buffer_list(),
                           };

                           audio_unit->audio_unit_render(parameters);
                       }
                   });

    if (wait > 0) {
        [NSThread sleepForTimeInterval:wait];
    }
}
