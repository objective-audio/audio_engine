//
//  yas_audio_unit_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit_node.h"

namespace yas
{
    class audio_unit_io_node : public audio_unit_node
    {
       public:
        static audio_unit_io_node_sptr create();

        virtual ~audio_unit_io_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(const audio_device_sptr &device);
        audio_device_sptr device() const;
#endif

        virtual bus_result_t next_available_output_bus() const override;
        virtual bool is_available_output_bus(const uint32_t bus_idx) const override;

        void set_channel_map(const channel_map_t &map, const yas::direction dir);
        const channel_map_t &channel_map(const yas::direction dir) const;

        Float64 device_sample_rate() const;
        uint32_t output_device_channel_count() const;
        uint32_t input_device_channel_count() const;

        virtual void update_connections() override;

       protected:
        audio_unit_io_node();

        virtual void prepare_audio_unit() override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_unit_node;
    };

    class audio_unit_output_node : public audio_unit_io_node
    {
       public:
        static audio_unit_output_node_sptr create();

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;

       protected:
        virtual void prepare_audio_unit() override;

       private:
        using super_class = audio_unit_io_node;
    };

    class audio_unit_input_node : public audio_unit_io_node
    {
       public:
        static audio_unit_input_node_sptr create();

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;

        virtual void update_connections() override;

       protected:
        audio_unit_input_node();

        virtual void prepare_audio_unit() override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_unit_io_node;

        std::weak_ptr<audio_unit_input_node> _weak_this;
    };
}
