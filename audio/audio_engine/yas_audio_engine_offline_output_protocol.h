//
//  yas_audio_engine_offline_output_protocol.h
//

#pragma once

#include <functional>
#include "yas_protocol.h"
#include "yas_result.h"

namespace yas::audio {
class pcm_buffer;
class time;
}

namespace yas::audio::engine {
enum class offline_start_error_t {
    already_running,
    prepare_failure,
    connection_not_found,
};

struct offline_render_args {
    audio::pcm_buffer &buffer;
    audio::time const &when;
    bool &out_stop;
};

using offline_render_f = std::function<void(offline_render_args)>;
using offline_completion_f = std::function<void(bool const cancelled)>;
using offline_start_result_t = result<std::nullptr_t, offline_start_error_t>;

struct manageable_offline_output : protocol {
    struct impl : protocol::impl {
        virtual offline_start_result_t start(offline_render_f &&, offline_completion_f &&) = 0;
        virtual void stop() = 0;
    };

    explicit manageable_offline_output(std::shared_ptr<impl> impl);
    manageable_offline_output(std::nullptr_t);

    offline_start_result_t start(offline_render_f &&, offline_completion_f &&);
    void stop();
};
}
