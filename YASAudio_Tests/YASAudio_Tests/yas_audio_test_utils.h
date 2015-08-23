//
//  yas_audio_test_utils.h
//  YASAudio_Tests
//
//  Created by Yuki Yasoshima on 2015/05/19.
//
//

#pragma once

#include "yas_audio.h"
#include <Foundation/Foundation.h>

@class YASAudioFormat;

namespace yas
{
    class audio_unit;
    class pcm_buffer;

    namespace test
    {
        UInt32 test_value(const UInt32 frame, const UInt32 ch_idx, const UInt32 buf_idx);
        void fill_test_values_to_buffer(pcm_buffer_ptr &buffer);
        bool is_cleard_buffer(pcm_buffer_ptr &data);
        bool is_filled_buffer(pcm_buffer_ptr &data);
        bool is_equal_buffer_flexibly(pcm_buffer_ptr &data1, pcm_buffer_ptr &data2);
        flex_pointer data_ptr_from_buffer(pcm_buffer_ptr &data, const UInt32 ch_idx, const UInt32 frame);

        void audio_unit_render_on_sub_thread(std::shared_ptr<audio_unit> audio_unit, yas::audio_format_ptr format,
                                             const UInt32 frame_length, const NSUInteger count,
                                             const NSTimeInterval wait);

        class audio_test_node;
        using audio_test_node_ptr = std::shared_ptr<audio_test_node>;

        class audio_test_node : public yas::audio_node
        {
           public:
            static audio_test_node_ptr create(const uint32_t input_bus_count = 2, const uint32_t output_bus_count = 1);
            uint32_t input_bus_count() const override;
            uint32_t output_bus_count() const override;

           private:
            uint32_t _input_bus_count;
            uint32_t _output_bus_count;
        };
    }
}
