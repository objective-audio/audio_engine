//
//  yas_audio_engine.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_result.h"
#include "yas_observing.h"
#include "yas_audio_connection.h"
#include <set>

namespace yas
{
    namespace audio_engine_method
    {
        static const auto configuration_change = "yas.audio_engine.configuration_change";
    }

    class audio_engine
    {
       public:
        enum class start_error_t {
            already_running,
            prepare_failure,
            connection_not_found,
            offline_output_not_found,
            offline_output_starting_failure,
        };

        using start_result_t = yas::result<std::nullptr_t, start_error_t>;

        audio_engine(std::nullptr_t n = nullptr);

        ~audio_engine() = default;

        audio_engine(const audio_engine &) = default;
        audio_engine(audio_engine &&) = default;
        audio_engine &operator=(const audio_engine &) = default;
        audio_engine &operator=(audio_engine &&) = default;

        bool operator==(const audio_engine &) const;
        bool operator!=(const audio_engine &) const;

        explicit operator bool() const;

        void prepare();

        audio_connection connect(const audio_node_sptr &source_node, const audio_node_sptr &destination_node,
                                 const audio_format &format);
        audio_connection connect(const audio_node_sptr &source_node, const audio_node_sptr &destination_node,
                                 const UInt32 source_bus_idx, const UInt32 destination_bus_idx,
                                 const audio_format &format);

        void disconnect(audio_connection &connectiion);
        void disconnect(const audio_node_sptr &node);
        void disconnect_input(const audio_node_sptr &node);
        void disconnect_input(const audio_node_sptr &node, const UInt32 bus_idx);
        void disconnect_output(const audio_node_sptr &node);
        void disconnect_output(const audio_node_sptr &node, const UInt32 bus_idx);

        start_result_t start_render();
        start_result_t start_offline_render(const offline_render_f &render_function,
                                            const offline_completion_f &completion_function);
        void stop();

        subject &subject() const;

       private:
        class impl;
        std::shared_ptr<impl> _impl;
        
        audio_engine(const std::shared_ptr<impl> &);

        void _reload_graph();
        void _post_configuration_change() const;

        std::set<audio_node_sptr> &_nodes() const;
        audio_connection_map &_connections() const;

       public:
        class private_access;
        friend private_access;

        using weak = weak<audio_engine>;
        friend weak;
    };

    std::string to_string(const audio_engine::start_error_t &error);
}

#include "yas_audio_engine_private_access.h"
