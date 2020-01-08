//
//  yas_audio_test_utils.h
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#pragma once

#import <audio/audio.h>

namespace yas::test {
uint32_t test_value(uint32_t const frame, uint32_t const ch_idx, uint32_t const buf_idx);
void fill_test_values_to_buffer(audio::pcm_buffer &buffer);
bool is_cleared_buffer(audio::pcm_buffer const &data);
bool is_filled_buffer(audio::pcm_buffer const &data);
bool is_equal_buffer_flexibly(audio::pcm_buffer const &data1, audio::pcm_buffer const &data2);
uint8_t const *data_ptr_from_buffer(audio::pcm_buffer const &data, uint32_t const ch_idx, uint32_t const frame);
bool is_equal(double const val1, double const val2, double const accuracy = 0);
bool is_equal_data(void const *const inData1, void const *const inData2, const size_t inSize);
bool is_equal(AudioTimeStamp const *const ts1, AudioTimeStamp const *const ts2);

struct node_object {
    node_object(uint32_t const input_bus_count = 2, uint32_t const output_bus_count = 1);

    audio::graph_node_ptr node;
};
}  // namespace yas::test
