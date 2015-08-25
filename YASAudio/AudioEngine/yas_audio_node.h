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
    class audio_node_core
    {
       public:
        audio_node_core();
        virtual ~audio_node_core();

        audio_connection_wmap input_connections;
        audio_connection_wmap output_connections;

        audio_connection_sptr input_connection(const uint32_t bus_idx);
        audio_connection_sptr output_connection(const uint32_t bus_idx);

       private:
        audio_node_core(const audio_node_core &) = delete;
        audio_node_core(audio_node_core &&) = delete;
        audio_node_core &operator=(const audio_node_core &) = delete;
        audio_node_core &operator=(audio_node_core &&) = delete;
    };

    using audio_node_core_ptr = std::shared_ptr<audio_node_core>;

    class audio_node
    {
       public:
        virtual ~audio_node();

        bool operator==(const audio_node &);

        void reset();

        audio_format_sptr input_format(const uint32_t bus_idx);
        audio_format_sptr output_format(const uint32_t bus_idx);
        virtual bus_result next_available_input_bus() const;
        virtual bus_result next_available_output_bus() const;
        virtual bool is_available_input_bus(const uint32_t bus_idx) const;
        virtual bool is_available_output_bus(const uint32_t bus_idx) const;
        audio_engine_sptr engine() const;
        audio_time_sptr last_render_time() const;

        virtual uint32_t input_bus_count() const;
        virtual uint32_t output_bus_count() const;

        virtual void render(const audio_pcm_buffer_sptr &buffer, const uint32_t bus_idx, const audio_time_sptr &when);

       protected:
        audio_node();

        audio_connection_sptr input_connection(const uint32_t bus_idx) const;
        audio_connection_sptr output_connection(const uint32_t bus_idx) const;
        const audio_connection_wmap &input_connections() const;
        const audio_connection_wmap &output_connections() const;

        audio_node_core_ptr node_core() const;

        virtual void update_connections();
        virtual audio_node_core_ptr make_node_core();
        virtual void prepare_node_core(const audio_node_core_ptr &node_core);  // NS_REQUIRES_SUPER
        void update_node_core();

        void set_render_time_on_render(const audio_time_sptr &time);

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_node(const audio_node &) = delete;
        audio_node(audio_node &&) = delete;
        audio_node &operator=(const audio_node &) = delete;
        audio_node &operator=(audio_node &&) = delete;

        void _set_engine(const audio_engine_sptr &engine);
        void _add_connection(const audio_connection_sptr &connection);
        void _remove_connection(const audio_connection &connection);

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_node_private_access.h"
