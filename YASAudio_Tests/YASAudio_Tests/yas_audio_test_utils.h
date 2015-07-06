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

@class YASAudioFormat;

namespace yas
{
    class audio_unit;
    class audio_data;

    namespace test
    {
        UInt32 test_value(const UInt32 frame, const UInt32 channel, const UInt32 buffer);
        void fill_test_values_to_data(audio_data_ptr &data);
        bool is_cleard_data(audio_data_ptr &data);
        bool is_filled_data(audio_data_ptr &data);
        bool is_equal_data_flexibly(audio_data_ptr &data1, audio_data_ptr &data2);
        audio_pointer data_ptr_from_data(audio_data_ptr &data, const UInt32 channel, const UInt32 frame);

        void audio_unit_render_on_sub_thread(std::shared_ptr<audio_unit> audio_unit, yas::audio_format_ptr format,
                                             const UInt32 frame_length, const NSUInteger count,
                                             const NSTimeInterval wait);
    }
}
