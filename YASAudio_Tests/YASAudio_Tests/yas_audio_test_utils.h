//
//  yas_audio_test_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>

#pragma once

#include "yas_audio.h"

@class YASAudioFormat;

namespace yas
{
    class audio_unit;
    class pcm_buffer;

    namespace test
    {
        UInt32 test_value(const UInt32 frame, const UInt32 ch_idx, const UInt32 buf_idx);
        void fill_test_values_to_buffer(const audio_pcm_buffer_sptr &buffer);
        bool is_cleared_buffer(const audio_pcm_buffer_sptr &data);
        bool is_filled_buffer(const audio_pcm_buffer_sptr &data);
        bool is_equal_buffer_flexibly(const audio_pcm_buffer_sptr &data1, const audio_pcm_buffer_sptr &data2);
        flex_pointer data_ptr_from_buffer(const audio_pcm_buffer_sptr &data, const UInt32 ch_idx, const UInt32 frame);
        bool is_equal(const Float64 val1, const Float64 val2, const Float64 accuracy = 0);
        bool is_equal_data(const void *inData1, const void *inData2, const size_t inSize);
        bool is_equal(const AudioTimeStamp *ts1, const AudioTimeStamp *ts2);

        void audio_unit_render_on_sub_thread(std::shared_ptr<audio_unit> audio_unit, yas::audio_format_sptr format,
                                             const UInt32 frame_length, const NSUInteger count,
                                             const NSTimeInterval wait);

        class audio_test_node;
        using audio_test_node_sptr = std::shared_ptr<audio_test_node>;

        class audio_test_node : public yas::audio_node
        {
           public:
            static audio_test_node_sptr create(const UInt32 input_bus_count = 2, const UInt32 output_bus_count = 1);
            UInt32 input_bus_count() const override;
            UInt32 output_bus_count() const override;

           private:
            UInt32 _input_bus_count;
            UInt32 _output_bus_count;
        };
    }
}
