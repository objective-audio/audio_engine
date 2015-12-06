//
//  yas_audio_offline_output_node_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_result.h"
#include <functional>

namespace yas
{
    namespace audio
    {
        class pcm_buffer;
        class time;

        enum class offline_start_error_t {
            already_running,
            prepare_failure,
            connection_not_found,
        };

        using offline_render_f = std::function<void(audio::pcm_buffer &buffer, const audio::time &when, bool &stop)>;
        using offline_completion_f = std::function<void(const bool cancelled)>;
        using offline_start_result_t = yas::result<std::nullptr_t, offline_start_error_t>;

        class offline_output_unit_from_engine
        {
           public:
            virtual ~offline_output_unit_from_engine() = default;

            virtual offline_start_result_t _start(const offline_render_f &, const offline_completion_f &) const = 0;
            virtual void _stop() const = 0;
        };
    }
}