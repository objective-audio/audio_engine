//
//  yas_audio_device_io.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <functional>
#include "yas_audio_time.h"
#include "yas_audio_types.h"
#include <cpp_utils/yas_weakable.h>

namespace yas::audio {
class pcm_buffer;
class device;

    struct device_io : weakable<device_io> {
    struct render_args {
        std::shared_ptr<audio::pcm_buffer> &output_buffer;
        std::optional<audio::time> const when;
    };

    using render_f = std::function<void(render_args)>;

    device_io(std::nullptr_t);
    explicit device_io(std::shared_ptr<audio::device> const &);

    void set_device(std::shared_ptr<audio::device> const device);
    std::shared_ptr<audio::device> const &device() const;
    bool is_running() const;
    void set_render_handler(render_f);
    void set_maximum_frames_per_slice(uint32_t const frames);
    uint32_t maximum_frames_per_slice() const;

    void start() const;
    void stop() const;

    std::shared_ptr<pcm_buffer> &input_buffer_on_render();
    std::shared_ptr<audio::time> const &input_time_on_render() const;

    std::shared_ptr<weakable_impl> weakable_impl_ptr() const override;
   private:
    class kernel;
    class impl;
    
    std::shared_ptr<impl> _impl;

    void _initialize() const;
    void _uninitialize() const;
};
}  // namespace yas::audio

#endif
