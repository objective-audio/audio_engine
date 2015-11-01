//
//  yas_audio_offline_output_node_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_result.h"
#include <functional>

namespace yas
{
    enum class offline_start_error_t {
        already_running,
        prepare_failure,
        connection_not_found,
    };

    class audio_pcm_buffer;
    class audio_time;

    using offline_render_f = std::function<void(audio_pcm_buffer &buffer, const audio_time &when, bool &stop)>;
    using offline_completion_f = std::function<void(const bool cancelled)>;
    using offline_start_result_t = yas::result<std::nullptr_t, offline_start_error_t>;

    class audio_offline_output_unit_from_engine
    {
       public:
        virtual ~audio_offline_output_unit_from_engine() = default;

        virtual offline_start_result_t _start(const offline_render_f &, const offline_completion_f &) = 0;
        virtual void _stop() = 0;
    };
}