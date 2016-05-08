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

    class node : public base {
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

        audio::connectable_node connectable();
        audio::manageable_node const manageable_node() const;
        audio::manageable_node manageable_node();

       protected:
        class manageable_kernel;
        class impl;

        explicit node(std::shared_ptr<impl> const &);

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };

    class node::manageable_kernel {
       public:
        virtual ~manageable_kernel() = default;
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
