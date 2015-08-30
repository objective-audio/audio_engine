//
//  yas_audio_engine.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_result.h"
#include "yas_observing.h"
#include "yas_audio_offline_output_node.h"
#include <set>

namespace yas
{
    class audio_engine
    {
       public:
        enum class notification_method : uint32_t {
            configulation_change,
        };

        using subject_t = subject<notification_method>;
        using observer_ptr = observer<notification_method>::sptr;

        enum class start_error_t {
            already_running,
            prepare_failure,
            connection_not_found,
            offline_output_not_found,
            offline_output_starting_failure,
        };

        using start_result = yas::result<std::nullptr_t, start_error_t>;

        using offline_render_f = audio_offline_output_node::render_f;
        using offline_completion_f = audio_offline_output_node::completion_f;

        static audio_engine_sptr create();

        ~audio_engine();

        audio_connection_sptr connect(const audio_node_sptr &source_node, const audio_node_sptr &destination_node,
                                      const audio_format_sptr &format);
        audio_connection_sptr connect(const audio_node_sptr &source_node, const audio_node_sptr &destination_node,
                                      const uint32_t source_bus_idx, const uint32_t destination_bus_idx,
                                      const audio_format_sptr &format);

        void disconnect(const audio_connection_sptr &connectiion);
        void disconnect(const audio_node_sptr &node);
        void disconnect_input(const audio_node_sptr &node);
        void disconnect_input(const audio_node_sptr &node, const uint32_t bus_idx);
        void disconnect_output(const audio_node_sptr &node);
        void disconnect_output(const audio_node_sptr &node, const uint32_t bus_idx);

        start_result start_render();
        start_result start_offline_render(const offline_render_f &render_function,
                                          const offline_completion_f &completion_function);
        void stop();

        subject_t &subject() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_engine();
        audio_engine(const audio_engine &) = delete;
        audio_engine(audio_engine &&) = delete;
        audio_engine &operator=(const audio_engine &) = delete;
        audio_engine &operator=(audio_engine &&) = delete;

        void _reload_graph();
        void _post_configuration_change() const;

        std::set<audio_node_sptr> &_nodes() const;
        std::set<audio_connection_sptr> &_connections() const;

       public:
        class private_access;
        friend private_access;
    };

    std::string to_string(const audio_engine::start_error_t &error);
}

#include "yas_audio_engine_private_access.h"
