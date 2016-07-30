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
    class time;
    class engine;

    class node : public base {
       public:
        class impl;
        class kernel;

        enum class method {
            will_reset,
            update_connections,
        };

        using subject_t = subject<node, method>;
        using observer_t = observer<node, method>;

        enum class kernel_method {
            did_prepare,
        };

        using kernel_subject_t = subject<kernel, kernel_method>;
        using kernel_observer_t = observer<kernel, kernel_method>;

        using make_kernel_f = std::function<node::kernel(void)>;
        using render_f = std::function<void(audio::pcm_buffer &, uint32_t const, audio::time const &)>;

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

        void set_make_kernel_handler(make_kernel_f);
        void set_render_handler(render_f);

        void render(audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when);
        void set_render_time_on_render(audio::time const &time);

        subject_t &subject();
        kernel_subject_t &kernel_subject();

        audio::connectable_node &connectable();
        audio::manageable_node const &manageable() const;
        audio::manageable_node &manageable();

       protected:
        class manageable_kernel;

        explicit node(std::shared_ptr<impl> const &);

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

#include "yas_audio_node_impl.h"
