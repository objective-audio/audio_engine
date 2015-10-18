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
        static audio_unit_io_node_sptr create();

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
        class impl : public super_class::impl
        {
           public:
            impl();
            virtual ~impl();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
            void set_device(const audio_device &device);
            audio_device device() const;
#endif
            Float64 device_sample_rate() const;
            UInt32 output_device_channel_count() const;
            UInt32 input_device_channel_count() const;

            virtual bus_result_t next_available_output_bus() const override;
            virtual bool is_available_output_bus(const UInt32 bus_idx) const override;

            virtual void update_connections() override;

            class core;
            std::unique_ptr<core> _core;

           private:
            using super_class = super_class::impl;
        };

        audio_unit_io_node(std::shared_ptr<impl> &&);

        impl *_impl_ptr() const;

        virtual void prepare_audio_unit() override;
    };

    class audio_unit_output_node : public audio_unit_io_node
    {
       public:
        static audio_unit_output_node_sptr create();

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;

       protected:
        virtual void prepare_audio_unit() override;

       private:
        using super_class = audio_unit_io_node;
        class impl;

        audio_unit_output_node();
    };

    class audio_unit_input_node : public audio_unit_io_node
    {
       public:
        static audio_unit_input_node_sptr create();

        void set_channel_map(const channel_map_t &map);
        const channel_map_t &channel_map() const;

       protected:
        audio_unit_input_node();

        virtual void prepare_audio_unit() override;

       private:
        using super_class = audio_unit_io_node;
        class impl;

        audio_unit_input_node(const std::shared_ptr<audio_unit_input_node::impl> &);

        impl *_impl_ptr() const;

       public:
        using weak = yas::weak<audio_unit_input_node, audio_unit_input_node::impl>;
        friend weak;
    };
}
