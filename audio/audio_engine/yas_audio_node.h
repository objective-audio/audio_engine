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
#include "yas_observing.h"
#include "yas_protocol.h"

namespace yas {
template <typename T, typename U>
class result;

namespace audio {
    namespace engine {
        class manager;
    }
    class time;
    class kernel;

    class node : public base {
       public:
        class impl;

        enum class method {
            will_reset,
            update_connections,
        };

        using subject_t = subject<node, method>;
        using observer_t = observer<node, method>;

        struct render_args {
            audio::pcm_buffer &buffer;
            uint32_t const bus_idx;
            audio::time const &when;
        };

        using prepare_kernel_f = std::function<void(kernel &)>;
        using render_f = std::function<void(render_args)>;

        node(node_args);
        node(std::nullptr_t);

        virtual ~node() final;

        void reset();

        audio::connection input_connection(uint32_t const bus_idx) const;
        audio::connection output_connection(uint32_t const bus_idx) const;
        audio::connection_wmap const &input_connections() const;
        audio::connection_wmap const &output_connections() const;

        audio::format input_format(uint32_t const bus_idx) const;
        audio::format output_format(uint32_t const bus_idx) const;
        bus_result_t next_available_input_bus() const;
        bus_result_t next_available_output_bus() const;
        bool is_available_input_bus(uint32_t const bus_idx) const;
        bool is_available_output_bus(uint32_t const bus_idx) const;
        audio::engine::manager manager() const;
        audio::time last_render_time() const;

        uint32_t input_bus_count() const;
        uint32_t output_bus_count() const;
        bool is_input_renderable() const;

        void set_prepare_kernel_handler(prepare_kernel_f);
        void set_render_handler(render_f);

        audio::kernel kernel() const;

        void render(render_args);
        void set_render_time_on_render(audio::time const &time);

        subject_t &subject();

        audio::connectable_node &connectable();
        audio::manageable_node const &manageable() const;
        audio::manageable_node &manageable();

       private:
        audio::connectable_node _connectable = nullptr;
        mutable audio::manageable_node _manageable = nullptr;
    };
}

std::string to_string(audio::node::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::node::method const &);

template <>
struct std::hash<yas::audio::node> {
    std::size_t operator()(yas::audio::node const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#include "yas_audio_kernel.h"
