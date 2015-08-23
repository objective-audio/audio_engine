//
//  yas_audio_engine.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_result.h"
#include "yas_observing.h"
#include <set>

namespace yas
{
    class audio_engine;
    class audio_node;
    class audio_time;
    class audio_connection;
    class pcm_buffer;
    class audio_format;

    using audio_engine_ptr = std::shared_ptr<audio_engine>;
    using audio_node_ptr = std::shared_ptr<audio_node>;
    using audio_time_ptr = std::shared_ptr<audio_time>;
    using audio_connection_ptr = std::shared_ptr<audio_connection>;
    using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
    using audio_format_ptr = std::shared_ptr<audio_format>;

    class audio_engine
    {
       public:
        enum class notification_method : uint32_t {
            configulation_change,
        };

        using notification_subject_type = subject<notification_method>;
        using notification_observer_ptr = observer<notification_method>::shared_ptr;

        enum class start_error_type {
            already_running,
            prepare_failure,
            connection_not_found,
            offline_output_not_found,
            offline_output_starting_failure,
        };

        using start_result = yas::result<std::nullptr_t, start_error_type>;

        using offline_render_function =
            std::function<void(const pcm_buffer_ptr &buffer, const audio_time_ptr &when, bool &stop)>;
        using offline_completion_function = std::function<void(const bool cancelled)>;

        static audio_engine_ptr create();

        ~audio_engine();

        audio_connection_ptr connect(const audio_node_ptr &source_node, const audio_node_ptr &destination_node,
                                     const audio_format_ptr &format);
        audio_connection_ptr connect(const audio_node_ptr &source_node, const audio_node_ptr &destination_node,
                                     const uint32_t source_bus_idx, const uint32_t destination_bus_idx,
                                     const audio_format_ptr &format);

        void disconnect(const audio_connection_ptr &connectiion);
        void disconnect(const audio_node_ptr &node);
        void disconnect_input(const audio_node_ptr &node);
        void disconnect_input(const audio_node_ptr &node, const uint32_t bus_idx);
        void disconnect_output(const audio_node_ptr &node);
        void disconnect_output(const audio_node_ptr &node, const uint32_t bus_idx);

        start_result start_render();
        start_result start_offline_render(const offline_render_function &render_function,
                                          const offline_completion_function &completion_function);
        void stop();

        notification_subject_type &subject() const;

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

        std::set<audio_node_ptr> &_nodes() const;
        std::set<audio_connection_ptr> &_connections() const;

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_engine_private_access.h"
