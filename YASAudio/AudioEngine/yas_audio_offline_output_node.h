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

        static audio_offline_output_node_sptr create();

        ~audio_offline_output_node();

        bool is_running() const;

       private:
        using super_class = audio_node;
        class impl;

        audio_offline_output_node();

        start_result_t _start(const offline_render_f &callback_func, const offline_completion_f &completion_func);
        void _stop();

        impl *_impl_ptr() const;

       public:
        class private_access;
        friend private_access;
    };

    std::string to_string(const audio_offline_output_node::start_error_t &error);
}

#include "yas_audio_offline_output_node_private_access.h"
