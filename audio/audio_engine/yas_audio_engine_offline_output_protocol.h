//
//  yas_audio_engine_offline_output_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>
#include <cpp_utils/yas_result.h>
#include <functional>
#include "yas_audio_types.h"

namespace yas::audio {
class pcm_buffer;
class time;
}  // namespace yas::audio

namespace yas::audio::engine {
enum class offline_start_error_t {
    already_running,
    prepare_failure,
    connection_not_found,
};

struct offline_render_args {
    audio::pcm_buffer &buffer;
    audio::time const &when;
};

using offline_render_f = std::function<continuation(offline_render_args)>;
using offline_completion_f = std::function<void(bool const cancelled)>;
using offline_start_result_t = result<std::nullptr_t, offline_start_error_t>;

class manageable_offline_output;
using manageable_offline_output_ptr = std::shared_ptr<manageable_offline_output>;

struct manageable_offline_output {
    virtual offline_start_result_t start(offline_render_f &&, offline_completion_f &&) = 0;
    virtual void stop() = 0;

    static manageable_offline_output_ptr cast(manageable_offline_output_ptr const &output) {
        return output;
    }
};
}  // namespace yas::audio::engine
