//
//  yas_audio_test_utils.h
//  YASAudio_Tests
//
//  Created by Yuki Yasoshima on 2015/05/19.
//
//

#pragma once

#include <Foundation/Foundation.h>
#include <memory>
#include "YASAudioTypes.h"
#include "yas_audio_format.h"
#include "yas_pcm_buffer.h"

@class YASAudioFormat;

namespace yas
{
    class audio_unit;
    class pcm_buffer;

    namespace test
    {
        UInt32 test_value(const UInt32 frame, const UInt32 channel, const UInt32 buffer);
        void fill_test_values_to_buffer(pcm_buffer_ptr &buffer);
        bool is_cleard_buffer(pcm_buffer_ptr &data);
        bool is_filled_buffer(pcm_buffer_ptr &data);
        bool is_equal_buffer_flexibly(pcm_buffer_ptr &data1, pcm_buffer_ptr &data2);
        flex_pointer data_ptr_from_buffer(pcm_buffer_ptr &data, const UInt32 channel, const UInt32 frame);

        void audio_unit_render_on_sub_thread(std::shared_ptr<audio_unit> audio_unit, yas::audio_format_ptr format,
                                             const UInt32 frame_length, const NSUInteger count,
                                             const NSTimeInterval wait);
    }
}
