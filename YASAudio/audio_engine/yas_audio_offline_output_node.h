//
//  yas_audio_offline_output_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"
#include "yas_audio_offline_output_node_protocol.h"

namespace yas
{
    class audio_offline_output_node : public audio_node, public audio_offline_output_unit_from_engine
    {
        using super_class = audio_node;

       public:
        class impl;

        audio_offline_output_node();
        audio_offline_output_node(std::nullptr_t);

        ~audio_offline_output_node();

        bool is_running() const;

       private:
        audio_offline_output_node(const std::shared_ptr<impl> &);

        // from engine

        offline_start_result_t _start(const offline_render_f &callback_func,
                                      const offline_completion_f &completion_func) const override;
        void _stop() const override;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };

    std::string to_string(const offline_start_error_t &error);
}

#include "yas_audio_offline_output_node_impl.h"

#if YAS_TEST
#include "yas_audio_offline_output_node_private_access.h"
#endif
