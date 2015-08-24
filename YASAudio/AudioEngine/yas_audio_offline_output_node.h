//
//  yas_audio_offline_output_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas
{
    class audio_offline_output_node;

    using audio_offline_output_node_ptr = std::shared_ptr<audio_offline_output_node>;

    class audio_offline_output_node : public audio_node
    {
        enum class start_error_type {
            already_running,
            prepare_failure,
            connection_not_found,
        };

        using start_result = yas::result<std::nullptr_t, start_error_type>;

       public:
        static audio_offline_output_node_ptr create();

        ~audio_offline_output_node();

        uint32_t output_bus_count() const override;
        uint32_t input_bus_count() const override;

        bool is_running() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_unit_node;
        using render_function =
            std::function<void(const pcm_buffer_ptr &buffer, const audio_time_ptr &when, bool &stop)>;
        using completion_function = std::function<void(const bool cancelled)>;

        audio_offline_output_node();

        start_result _start(const render_function &callback_func, const completion_function &completion_func);
        void _stop();

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_offline_output_node_private_access.h"
