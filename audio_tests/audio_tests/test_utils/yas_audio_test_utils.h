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
    uint32_t test_value(uint32_t const frame, uint32_t const ch_idx, uint32_t const buf_idx);
    void fill_test_values_to_buffer(audio::pcm_buffer const &buffer);
    bool is_cleared_buffer(audio::pcm_buffer const &data);
    bool is_filled_buffer(audio::pcm_buffer const &data);
    bool is_equal_buffer_flexibly(audio::pcm_buffer const &data1, audio::pcm_buffer const &data2);
    flex_ptr data_ptr_from_buffer(audio::pcm_buffer const &data, uint32_t const ch_idx, uint32_t const frame);
    bool is_equal(double const val1, double const val2, double const accuracy = 0);
    bool is_equal_data(void const *const inData1, void const *const inData2, const size_t inSize);
    bool is_equal(AudioTimeStamp const *const ts1, AudioTimeStamp const *const ts2);

    void audio_unit_render_on_sub_thread(audio::unit &audio_unit, audio::format &format, uint32_t const frame_length,
                                         std::size_t const count, NSTimeInterval const wait);

    class audio_test_node : public yas::audio::node {
        class impl;

       public:
        audio_test_node(uint32_t const input_bus_count = 2, uint32_t const output_bus_count = 1);

        void set_input_bus_count(uint32_t const &);
        void set_output_bus_count(uint32_t const &);
    };

    struct connection : audio::connection {
        connection(audio::node &source_node, uint32_t const source_bus, audio::node &destination_node,
                   uint32_t const destination_bus, audio::format const &format);
    };

    struct node : audio::node {
        node();
        node(audio::node const &);

        audio::node::kernel kernel();
    };

    struct unit : audio::unit {
        template <typename T>
        void set_property_data(std::vector<T> const &data, AudioUnitPropertyID const property_id,
                               AudioUnitScope const scope, AudioUnitElement const element) {
            impl_ptr<audio::unit::impl>()->set_property_data(data, property_id, scope, element);
        }

        template <typename T>
        std::vector<T> property_data(AudioUnitPropertyID const property_id, AudioUnitScope const scope,
                                     AudioUnitElement const element) {
            return impl_ptr<audio::unit::impl>()->property_data<T>(property_id, scope, element);
        }
    };
}
}
