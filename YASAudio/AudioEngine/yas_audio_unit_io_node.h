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
        virtual ~audio_unit_io_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(const audio_device_sptr &device);
        audio_device_sptr device() const;
#endif

        virtual bus_result_t next_available_output_bus() const override;
        virtual bool is_available_output_bus(const uint32_t bus_idx) const override;

        void set_output_channel_map(const channel_map &map, const AudioUnitElement element);
        const channel_map &output_channel_map(const AudioUnitElement element) const;
        void set_input_channel_map(const channel_map &map, const AudioUnitElement element);
        const channel_map &input_channel_map(const AudioUnitElement element) const;

        uint32_t output_device_channel_count() const;
        uint32_t input_device_channel_count() const;

       protected:
        audio_unit_io_node();

        void prepare_audio_unit() override;
        void prepare_parameters() override;

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

        void set_output_channel_map(const channel_map &map);
        const channel_map &output_channel_map() const;
        void set_input_channel_map(const channel_map &map);
        const channel_map &input_channel_map() const;

       protected:
        void prepare_audio_unit() override;

       private:
        using super_class = audio_unit_io_node;
    };

    class audio_unit_input_node : public audio_unit_io_node
    {
       public:
        static audio_unit_input_node_sptr create();

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;

        void update_connections() override;

        void set_output_channel_map(const channel_map &map);
        const channel_map &output_channel_map() const;
        void set_input_channel_map(const channel_map &map);
        const channel_map &input_channel_map() const;

       protected:
        audio_unit_input_node();

        void prepare_audio_unit() override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_unit_io_node;

        std::weak_ptr<audio_unit_input_node> _weak_this;
    };
}
