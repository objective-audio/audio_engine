//
//  yas_audio_device_io.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <functional>
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class pcm_buffer;
    class time;
    class device;

    class device_io : public base {
       public:
        struct render_args {
            audio::pcm_buffer &output_buffer;
            audio::time const &when;
        };

        using render_f = std::function<void(render_args)>;

        device_io(std::nullptr_t);
        explicit device_io(audio::device const &);

        void set_device(audio::device const device);
        audio::device device() const;
        bool is_running() const;
        void set_render_handler(render_f);
        void set_maximum_frames_per_slice(uint32_t const frames);
        uint32_t maximum_frames_per_slice() const;

        void start() const;
        void stop() const;

        audio::pcm_buffer const &input_buffer_on_render() const;
        audio::time const &input_time_on_render() const;

       private:
        class kernel;
        class impl;

        void _initialize() const;
        void _uninitialize() const;
    };
}
}

template <>
struct std::hash<yas::audio::device_io> {
    std::size_t operator()(yas::audio::device_io const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#endif
