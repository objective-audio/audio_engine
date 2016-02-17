//
//  yas_audio_node.h
//

#pragma once

#include <experimental/optional>
#include <map>
#include <memory>
#include "yas_audio_connection.h"
#include "yas_audio_format.h"
#include "yas_audio_node_protocol.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_result.h"

namespace yas {
namespace audio {
    class time;
    class engine;

    class node : public base, public node_from_engine, public node_from_connection {
        using super_class = base;

       public:
        class kernel;

        explicit node(std::nullptr_t);
        virtual ~node();

        node(node const &) = default;
        node(node &&) = default;
        node &operator=(node const &) = default;
        node &operator=(node &&) = default;
        node &operator=(std::nullptr_t);

        void reset();

        audio::format input_format(UInt32 const bus_idx) const;
        audio::format output_format(UInt32 const bus_idx) const;
        bus_result_t next_available_input_bus() const;
        bus_result_t next_available_output_bus() const;
        bool is_available_input_bus(UInt32 const bus_idx) const;
        bool is_available_output_bus(UInt32 const bus_idx) const;
        audio::engine engine() const;
        audio::time last_render_time() const;

        UInt32 input_bus_count() const;
        UInt32 output_bus_count() const;

        void render(audio::pcm_buffer &buffer, UInt32 const bus_idx, audio::time const &when);
        void set_render_time_on_render(audio::time const &time);

       protected:
        class kernel_from_node;
        class impl;

        explicit node(std::shared_ptr<impl> const &);

        // from engine

        audio::connection _input_connection(UInt32 const bus_idx) const override;
        audio::connection _output_connection(UInt32 const bus_idx) const override;
        audio::connection_wmap const &_input_connections() const override;
        audio::connection_wmap const &_output_connections() const override;
        void _add_connection(audio::connection const &connection) override;
        void _remove_connection(audio::connection const &connection) override;
        void _set_engine(audio::engine const &engine) override;
        audio::engine _engine() const override;
        void _update_kernel() override;
        void _update_connections() override;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };

    class node::kernel_from_node {
       public:
        virtual ~kernel_from_node() = default;
        virtual void _set_input_connections(audio::connection_wmap const &) = 0;
        virtual void _set_output_connections(audio::connection_wmap const &) = 0;
    };
}
}

template <>
struct std::hash<yas::audio::node> {
    std::size_t operator()(yas::audio::node const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#include "yas_audio_node_impl.h"
#include "yas_audio_node_kernel.h"

#if YAS_TEST
#include "yas_audio_node_private_access.h"
#endif
