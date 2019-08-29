//
//  yas_audio_device_io.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <functional>
#include "yas_audio_engine_ptr.h"
#include "yas_audio_time.h"
#include "yas_audio_types.h"

namespace yas::audio {
class pcm_buffer;

struct device_io final : std::enable_shared_from_this<device_io> {
    class impl;

    struct render_args {
        audio::pcm_buffer_ptr const &output_buffer;
        std::optional<audio::time> const when;
    };

    using render_f = std::function<void(render_args)>;

    void set_device(audio::device_ptr const device);
    audio::device_ptr const &device() const;
    bool is_running() const;
    void set_render_handler(render_f);
    void set_maximum_frames_per_slice(uint32_t const frames);
    uint32_t maximum_frames_per_slice() const;

    void start() const;
    void stop() const;

    pcm_buffer_ptr const &input_buffer_on_render();
    audio::time_ptr const &input_time_on_render() const;

   private:
    class kernel;

    std::shared_ptr<impl> _impl;

    device_io();

    void _prepare(audio::device_ptr const &);

    void _initialize() const;
    void _uninitialize() const;

   public:
    static audio::device_io_ptr make_shared(audio::device_ptr const &);
};

}  // namespace yas::audio

#endif
