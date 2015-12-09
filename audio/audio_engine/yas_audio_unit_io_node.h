//
//  yas_audio_unit_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit_node.h"

namespace yas {
namespace audio {
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class device;
#endif
    class unit_io_node : public unit_node {
        using super_class = unit_node;

       public:
        unit_io_node();
        unit_io_node(std::nullptr_t);

        virtual ~unit_io_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(const audio::device &device);
        audio::device device() const;
#endif

        void set_channel_map(const channel_map_t &map, const direction dir);
        const channel_map_t &channel_map(const direction dir) const;

        Float64 device_sample_rate() const;
        UInt32 output_device_channel_count() const;
        UInt32 input_device_channel_count() const;

       protected:
        class impl;

        unit_io_node(const std::shared_ptr<impl> &, const AudioComponentDescription &);
    };

    class unit_output_node : public unit_io_node {
        using super_class = unit_io_node;

       public:
        class impl;

        unit_output_node();
        unit_output_node(std::nullptr_t);

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;
    };

    class unit_input_node : public unit_io_node {
        using super_class = unit_io_node;

       public:
        class impl;

        unit_input_node();
        unit_input_node(std::nullptr_t);

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;
    };
}
}

#include "yas_audio_unit_io_node_impl.h"
