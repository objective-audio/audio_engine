//
//  yas_audio_unit_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_unit_node.h"

namespace yas
{
    class audio_unit_output_node;
    using audio_unit_output_node_ptr = std::shared_ptr<audio_unit_output_node>;
    class audio_unit_input_node;
    using audio_unit_input_node_ptr = std::shared_ptr<audio_unit_input_node>;
    class audio_device;
    using audio_device_ptr = std::shared_ptr<audio_device>;

    class audio_unit_io_node : public audio_unit_node
    {
       public:
        virtual ~audio_unit_io_node();

        void set_output_channel_map(const channel_map &);
        const channel_map &output_channel_map() const;
        void set_input_channel_map(const channel_map &);
        const channel_map &input_channel_map() const;

#if TARGET_OS_IPHONE
/*
@property (nonatomic, strong) NSArray *outputChannelAssignments;
@property (nonatomic, strong) NSArray *inputChannelAssignments;
 */
#elif TARGET_OS_MAC
        void set_device(const audio_device_ptr &device);
        audio_device_ptr device() const;
#endif

        virtual bus_result next_available_output_bus() const override;
        virtual bool is_available_output_bus(const uint32_t bus_idx) const override;

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
        static audio_unit_output_node_ptr create();

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;

       protected:
        void prepare_audio_unit() override;

       private:
        using super_class = audio_unit_io_node;
    };

    class audio_unit_input_node : public audio_unit_io_node, public std::enable_shared_from_this<audio_unit_input_node>
    {
       public:
        static audio_unit_input_node_ptr create();

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;

        void update_connections() override;

       protected:
        audio_unit_input_node();

        void prepare_audio_unit() override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_unit_io_node;
    };
}
