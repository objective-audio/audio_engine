//
//  yas_audio_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_node_protocol.h"
#include "yas_result.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_connection.h"
#include "yas_base.h"
#include <memory>
#include <map>
#include <experimental/optional>

namespace yas
{
    class audio_engine;
    class audio_time;

    class audio_node : public base, public audio_node_from_engine, public audio_node_from_connection
    {
        using super_class = base;

       public:
        class kernel;

        struct create_tag_t {
        };
        constexpr static create_tag_t create_tag{};

        explicit audio_node(std::nullptr_t);
        virtual ~audio_node();

        audio_node(const audio_node &) = default;
        audio_node(audio_node &&) = default;
        audio_node &operator=(const audio_node &) = default;
        audio_node &operator=(audio_node &&) = default;
        audio_node &operator=(std::nullptr_t);

        void reset();

        audio_format input_format(const UInt32 bus_idx) const;
        audio_format output_format(const UInt32 bus_idx) const;
        bus_result_t next_available_input_bus() const;
        bus_result_t next_available_output_bus() const;
        bool is_available_input_bus(const UInt32 bus_idx) const;
        bool is_available_output_bus(const UInt32 bus_idx) const;
        audio_engine engine() const;
        audio_time last_render_time() const;

        UInt32 input_bus_count() const;
        UInt32 output_bus_count() const;

        void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);
        void set_render_time_on_render(const audio_time &time);

       protected:
        class kernel_from_node;
        class impl;

        explicit audio_node(const std::shared_ptr<impl> &);

        // from engine

        audio_connection _input_connection(const UInt32 bus_idx) const override;
        audio_connection _output_connection(const UInt32 bus_idx) const override;
        const audio_connection_wmap &_input_connections() const override;
        const audio_connection_wmap &_output_connections() const override;
        void _add_connection(const audio_connection &connection) override;
        void _remove_connection(const audio_connection &connection) override;
        void _set_engine(const audio_engine &engine) override;
        audio_engine _engine() const override;
        void _update_kernel() override;
        void _update_connections() override;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };

    class audio_node::kernel_from_node
    {
       public:
        virtual ~kernel_from_node() = default;
        virtual void _set_input_connections(const audio_connection_wmap &) = 0;
        virtual void _set_output_connections(const audio_connection_wmap &) = 0;
    };
}

template <>
struct std::hash<yas::audio_node> {
    std::size_t operator()(yas::audio_node const &key) const
    {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#include "yas_audio_node_kernel.h"
#include "yas_audio_node_impl.h"

#if YAS_TEST
#include "yas_audio_node_private_access.h"
#endif
