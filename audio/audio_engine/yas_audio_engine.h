//
//  yas_audio_engine.h
//

#pragma once

#include "yas_audio_connection.h"
#include "yas_audio_offline_output_node_protocol.h"
#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_observing.h"
#include "yas_result.h"

namespace yas {
namespace audio {
    class graph;
    class offline_output_node;

    class engine : public base {
        class impl;

       public:
        static auto constexpr configuration_change_key = "yas.audio.engine.configuration_change";

        enum class start_error_t {
            already_running,
            prepare_failure,
            connection_not_found,
            offline_output_not_found,
            offline_output_starting_failure,
        };

        using start_result_t = result<std::nullptr_t, start_error_t>;

        engine();
        engine(std::nullptr_t);
        ~engine();

        engine(engine const &) = default;
        engine(engine &&) = default;
        engine &operator=(engine const &) = default;
        engine &operator=(engine &&) = default;

        engine &operator=(std::nullptr_t);

        audio::connection connect(node &source_node, node &destination_node, audio::format const &format);
        audio::connection connect(node &source_node, node &destination_node, uint32_t const source_bus_idx,
                                  uint32_t const destination_bus_idx, audio::format const &format);

        void disconnect(audio::connection &);
        void disconnect(node &);
        void disconnect_input(node const &);
        void disconnect_input(node const &, uint32_t const bus_idx);
        void disconnect_output(node const &);
        void disconnect_output(node const &, uint32_t const bus_idx);

        start_result_t start_render();
        start_result_t start_offline_render(offline_render_f const &render_function,
                                            offline_completion_f const &completion_function);
        void stop();

        subject<engine> &subject() const;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}

std::string to_string(audio::engine::start_error_t const &error);
}

#include "yas_audio_engine_impl.h"

#if YAS_TEST
#include "yas_audio_engine_private_access.h"
#endif
