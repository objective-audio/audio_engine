//
//  yas_audio_offline_output_node_protocol.h
//

#pragma once

#include <functional>
#include "yas_result.h"

namespace yas {
namespace audio {
    class pcm_buffer;
    class time;

    enum class offline_start_error_t {
        already_running,
        prepare_failure,
        connection_not_found,
    };

    using offline_render_f = std::function<void(audio::pcm_buffer &buffer, audio::time const &when, bool &out_stop)>;
    using offline_completion_f = std::function<void(bool const cancelled)>;
    using offline_start_result_t = yas::result<std::nullptr_t, offline_start_error_t>;

    class manageable_offline_output_unit {
       public:
        virtual ~manageable_offline_output_unit() = default;

        virtual offline_start_result_t _start(offline_render_f &&, offline_completion_f &&) const = 0;
        virtual void _stop() const = 0;
    };
}
}