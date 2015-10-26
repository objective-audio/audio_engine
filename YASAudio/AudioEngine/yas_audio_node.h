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
#include "yas_weak.h"
#include <memory>
#include <map>
#include <experimental/optional>

namespace yas
{
    class audio_engine;

    class audio_node
    {
       public:
        struct cast_tag_t {
        };
        struct create_tag_t {
        };
        constexpr static cast_tag_t cast_tag{};
        constexpr static create_tag_t create_tag{};

        explicit audio_node(std::nullptr_t);
        virtual ~audio_node();

        audio_node(const audio_node &) = default;
        audio_node(audio_node &&) = default;
        audio_node &operator=(const audio_node &) = default;
        audio_node &operator=(audio_node &&) = default;
        audio_node &operator=(std::nullptr_t);

        bool operator==(const audio_node &);
        bool operator!=(const audio_node &);

        bool expired() const;
        explicit operator bool() const;

        uintptr_t key() const;

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

        template <typename T>
        T cast() const
        {
            return T(*this, cast_tag);
        }

        void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);
        void set_render_time_on_render(const audio_time &time);

       protected:
        class kernel;
        class impl;

        explicit audio_node(std::shared_ptr<impl> &&, create_tag_t);
        audio_node(const std::shared_ptr<audio_node::impl> &);

        audio_connection input_connection(const UInt32 bus_idx) const;
        audio_connection output_connection(const UInt32 bus_idx) const;
        const audio_connection_wmap &input_connections() const;
        const audio_connection_wmap &output_connections() const;

        std::shared_ptr<impl> _impl;

       public:
        class private_access;
        friend private_access;

        friend weak<audio_node>;
    };
}

#include "yas_audio_node_kernel.h"
#include "yas_audio_node_impl.h"
#include "yas_audio_node_private_access.h"
