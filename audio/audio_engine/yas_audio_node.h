//
//  yas_audio_node.h
//

#pragma once

#include <experimental/optional>
#include "yas_audio_connection.h"
#include "yas_audio_format.h"
#include "yas_audio_node_protocol.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_protocol.h"

namespace yas {
template <typename T, typename U>
class result;

namespace audio {
    class time;
    class engine;

    class node : public base {
       public:
        class kernel;

        node(std::nullptr_t);

        void reset();

        audio::format input_format(uint32_t const bus_idx) const;
        audio::format output_format(uint32_t const bus_idx) const;
        bus_result_t next_available_input_bus() const;
        bus_result_t next_available_output_bus() const;
        bool is_available_input_bus(uint32_t const bus_idx) const;
        bool is_available_output_bus(uint32_t const bus_idx) const;
        audio::engine engine() const;
        audio::time last_render_time() const;

        uint32_t input_bus_count() const;
        uint32_t output_bus_count() const;

        void render(audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when);
        void set_render_time_on_render(audio::time const &time);

        audio::connectable_node connectable();
        audio::manageable_node const manageable_node() const;
        audio::manageable_node manageable_node();

       protected:
        class manageable_kernel;
        class impl;

        explicit node(std::shared_ptr<impl> const &);
    };

    struct node::manageable_kernel : protocol {
        struct impl : protocol::impl {
            virtual void set_input_connections(audio::connection_wmap &&) = 0;
            virtual void set_output_connections(audio::connection_wmap &&) = 0;
        };

        explicit manageable_kernel(std::shared_ptr<impl> &&impl) : protocol(std::move(impl)) {
        }

        void set_input_connections(audio::connection_wmap connections) {
            impl_ptr<impl>()->set_input_connections(std::move(connections));
        }

        void set_output_connections(audio::connection_wmap connections) {
            impl_ptr<impl>()->set_output_connections(std::move(connections));
        }
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
