//
//  yas_audio_engine.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_result.h"
#include "yas_observing.h"
#include "yas_audio_connection.h"
#include "yas_audio_offline_output_node_protocol.h"

namespace yas
{
    namespace audio_engine_method
    {
        static const auto configuration_change = "yas.audio.engine.configuration_change";
    }

    class audio_offline_output_node;

    namespace audio
    {
        class graph;

        class engine : public base
        {
            using super_class = base;
            class impl;

           public:
            enum class start_error_t {
                already_running,
                prepare_failure,
                connection_not_found,
                offline_output_not_found,
                offline_output_starting_failure,
            };

            using start_result_t = yas::result<std::nullptr_t, start_error_t>;

            engine();
            engine(std::nullptr_t);
            ~engine();

            engine(const engine &) = default;
            engine(engine &&) = default;
            engine &operator=(const engine &) = default;
            engine &operator=(engine &&) = default;

            engine &operator=(std::nullptr_t);

            audio::connection connect(audio_node &source_node, audio_node &destination_node,
                                      const audio::format &format);
            audio::connection connect(audio_node &source_node, audio_node &destination_node,
                                      const UInt32 source_bus_idx, const UInt32 destination_bus_idx,
                                      const audio::format &format);

            void disconnect(audio::connection &);
            void disconnect(audio_node &);
            void disconnect_input(const audio_node &);
            void disconnect_input(const audio_node &, const UInt32 bus_idx);
            void disconnect_output(const audio_node &);
            void disconnect_output(const audio_node &, const UInt32 bus_idx);

            start_result_t start_render();
            start_result_t start_offline_render(const offline_render_f &render_function,
                                                const offline_completion_f &completion_function);
            void stop();

            subject<engine> &subject() const;

#if YAS_TEST
           public:
            class private_access;
            friend private_access;
#endif
        };
    }

    std::string to_string(const audio::engine::start_error_t &error);
}

#include "yas_audio_engine_impl.h"

#if YAS_TEST
#include "yas_audio_engine_private_access.h"
#endif
