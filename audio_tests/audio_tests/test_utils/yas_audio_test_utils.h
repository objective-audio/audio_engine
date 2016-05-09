//
//  yas_audio_test_utils.h
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#pragma once

#include "yas_audio.h"

@class YASAudioFormat;

namespace yas {
namespace test {
    uint32_t test_value(const uint32_t frame, const uint32_t ch_idx, const uint32_t buf_idx);
    void fill_test_values_to_buffer(const audio::pcm_buffer &buffer);
    bool is_cleared_buffer(const audio::pcm_buffer &data);
    bool is_filled_buffer(const audio::pcm_buffer &data);
    bool is_equal_buffer_flexibly(const audio::pcm_buffer &data1, const audio::pcm_buffer &data2);
    flex_ptr data_ptr_from_buffer(const audio::pcm_buffer &data, const uint32_t ch_idx, const uint32_t frame);
    bool is_equal(const double val1, const double val2, const double accuracy = 0);
    bool is_equal_data(const void *const inData1, const void *const inData2, const size_t inSize);
    bool is_equal(const AudioTimeStamp *const ts1, const AudioTimeStamp *const ts2);

    void audio_unit_render_on_sub_thread(audio::unit &audio_unit, audio::format &format, const uint32_t frame_length,
                                         const NSUInteger count, const NSTimeInterval wait);

    class audio_test_node : public yas::audio::node {
        class impl;

       public:
        audio_test_node(const uint32_t input_bus_count = 2, const uint32_t output_bus_count = 1);

        void set_input_bus_count(const uint32_t &);
        void set_output_bus_count(const uint32_t &);
    };
}
}
