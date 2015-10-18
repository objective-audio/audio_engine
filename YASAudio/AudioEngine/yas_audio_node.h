//
//  yas_audio_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_result.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_connection.h"
#include <memory>
#include <map>
#include <experimental/optional>

namespace yas
{
    class audio_engine;

    class audio_node
    {
       public:
        virtual ~audio_node();

        bool operator==(const audio_node &);

        void reset();

        audio_format input_format(const UInt32 bus_idx);
        audio_format output_format(const UInt32 bus_idx);
        bus_result_t next_available_input_bus() const;
        bus_result_t next_available_output_bus() const;
        bool is_available_input_bus(const UInt32 bus_idx) const;
        bool is_available_output_bus(const UInt32 bus_idx) const;
        audio_engine engine() const;
        audio_time last_render_time() const;

        UInt32 input_bus_count() const;
        UInt32 output_bus_count() const;

        virtual void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);

       protected:
        class kernel
        {
           public:
            kernel();
            virtual ~kernel();

            audio_connection_smap input_connections() const;
            audio_connection_smap output_connections() const;
            audio_connection input_connection(const UInt32 bus_idx);
            audio_connection output_connection(const UInt32 bus_idx);

           private:
            class impl;
            std::unique_ptr<impl> _impl;

            kernel(const kernel &) = delete;
            kernel(kernel &&) = delete;
            kernel &operator=(const kernel &) = delete;
            kernel &operator=(kernel &&) = delete;

            void _set_input_connections(const audio_connection_wmap &);
            void _set_output_connections(const audio_connection_wmap &);

           public:
            class private_access;
            friend private_access;
        };

        class impl
        {
           public:
            impl();
            virtual ~impl();

            impl(const impl &) = delete;
            impl(impl &&) = delete;
            impl &operator=(const impl &) = delete;
            impl &operator=(impl &&) = delete;

            virtual bus_result_t next_available_input_bus() const;
            virtual bus_result_t next_available_output_bus() const;
            virtual bool is_available_input_bus(const UInt32 bus_idx) const;
            virtual bool is_available_output_bus(const UInt32 bus_idx) const;

            virtual UInt32 input_bus_count() const;
            virtual UInt32 output_bus_count() const;

            class core;
            std::unique_ptr<core> _core;
        };

        std::unique_ptr<impl> _impl;

        audio_node(std::unique_ptr<impl> &&);

        audio_connection input_connection(const UInt32 bus_idx) const;
        audio_connection output_connection(const UInt32 bus_idx) const;
        const audio_connection_wmap &input_connections() const;
        const audio_connection_wmap &output_connections() const;

        virtual void update_connections();
        virtual std::shared_ptr<kernel> make_kernel();
        virtual void prepare_kernel(const std::shared_ptr<kernel> &kernel);  // NS_REQUIRES_SUPER
        void update_kernel();

        std::shared_ptr<kernel> _kernel() const;

        // render thread
        void set_render_time_on_render(const audio_time &time);

       private:
        audio_node(const audio_node &) = delete;
        audio_node(audio_node &&) = delete;
        audio_node &operator=(const audio_node &) = delete;
        audio_node &operator=(audio_node &&) = delete;

        void _set_engine(const audio_engine &engine);
        void _add_connection(const audio_connection &connection);
        void _remove_connection(const audio_connection &connection);

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_node_private_access.h"
