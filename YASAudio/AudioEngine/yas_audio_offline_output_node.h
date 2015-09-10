//
//  yas_audio_offline_output_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas
{
    class audio_offline_output_node : public audio_node
    {
       public:
        enum class start_error_t {
            already_running,
            prepare_failure,
            connection_not_found,
        };

        using start_result_t = yas::result<std::nullptr_t, start_error_t>;
        using render_f =
            std::function<void(const audio_pcm_buffer_sptr &buffer, const audio_time_sptr &when, bool &stop)>;
        using completion_f = std::function<void(const bool cancelled)>;

        static audio_offline_output_node_sptr create();

        ~audio_offline_output_node();

        UInt32 output_bus_count() const override;
        UInt32 input_bus_count() const override;

        bool is_running() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_unit_node;

        audio_offline_output_node();

        start_result_t _start(const render_f &callback_func, const completion_f &completion_func);
        void _stop();

       public:
        class private_access;
        friend private_access;
    };

    std::string to_string(const audio_offline_output_node::start_error_t &error);
}

#include "yas_audio_offline_output_node_private_access.h"
