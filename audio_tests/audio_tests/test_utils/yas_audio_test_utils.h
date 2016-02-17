//
//  yas_audio_test_utils.h
//

#import <XCTest/XCTest.h>
#import <Foundation/Foundation.h>

#pragma once

#include "yas_audio.h"

@class YASAudioFormat;

namespace yas {
namespace test {
    UInt32 test_value(const UInt32 frame, const UInt32 ch_idx, const UInt32 buf_idx);
    void fill_test_values_to_buffer(const audio::pcm_buffer &buffer);
    bool is_cleared_buffer(const audio::pcm_buffer &data);
    bool is_filled_buffer(const audio::pcm_buffer &data);
    bool is_equal_buffer_flexibly(const audio::pcm_buffer &data1, const audio::pcm_buffer &data2);
    flex_ptr data_ptr_from_buffer(const audio::pcm_buffer &data, const UInt32 ch_idx, const UInt32 frame);
    bool is_equal(const Float64 val1, const Float64 val2, const Float64 accuracy = 0);
    bool is_equal_data(const void *const inData1, const void *const inData2, const size_t inSize);
    bool is_equal(const AudioTimeStamp *const ts1, const AudioTimeStamp *const ts2);

    void audio_unit_render_on_sub_thread(audio::unit &audio_unit, audio::format &format, const UInt32 frame_length,
                                         const NSUInteger count, const NSTimeInterval wait);

    class audio_test_node : public yas::audio::node {
        class impl;

       public:
        audio_test_node(const UInt32 input_bus_count = 2, const UInt32 output_bus_count = 1);

        void set_input_bus_count(const UInt32 &);
        void set_output_bus_count(const UInt32 &);
    };
}
}
