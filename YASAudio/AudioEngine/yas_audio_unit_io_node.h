//
//  yas_audio_unit_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit_node.h"

namespace yas
{
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class audio_device;
#endif

    class audio_unit_io_node : public audio_unit_node
    {
       public:
        audio_unit_io_node();
        audio_unit_io_node(std::nullptr_t);

        virtual ~audio_unit_io_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(const audio_device &device);
        audio_device device() const;
#endif

        void set_channel_map(const channel_map_t &map, const yas::direction dir);
        const channel_map_t &channel_map(const yas::direction dir) const;

        Float64 device_sample_rate() const;
        UInt32 output_device_channel_count() const;
        UInt32 input_device_channel_count() const;

       private:
        using super_class = audio_unit_node;

       protected:
        class impl;

        audio_unit_io_node(std::shared_ptr<impl> &&, create_tag_t);
        explicit audio_unit_io_node(const std::shared_ptr<impl> &);

        std::shared_ptr<impl> _impl_ptr() const;
    };

    class audio_unit_output_node : public audio_unit_io_node
    {
       public:
        audio_unit_output_node();
        audio_unit_output_node(std::nullptr_t);
        audio_unit_output_node(const audio_node &, audio_node::cast_tag_t);

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;

       private:
        using super_class = audio_unit_io_node;
        class impl;

        audio_unit_output_node(const std::shared_ptr<audio_unit_output_node::impl> &impl);

        friend weak<audio_unit_output_node>;
    };

    class audio_unit_input_node : public audio_unit_io_node
    {
       public:
        audio_unit_input_node();
        audio_unit_input_node(std::nullptr_t);
        audio_unit_input_node(const audio_node &, audio_node::cast_tag_t);

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;

       private:
        using super_class = audio_unit_io_node;
        class impl;

        audio_unit_input_node(const std::shared_ptr<audio_unit_input_node::impl> &);

        std::shared_ptr<impl> _impl_ptr() const;

        friend weak<audio_unit_input_node>;
    };
}

#include "yas_audio_unit_io_node_impl.h"
