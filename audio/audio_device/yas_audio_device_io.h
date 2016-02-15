//
//  yas_audio_device_io.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <functional>
#include <memory>
#include "yas_audio_device.h"
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class pcm_buffer;
    class time;

    class device_io : public base {
        using super_class = base;

       public:
        using render_f = std::function<void(audio::pcm_buffer &output_buffer, audio::time const &when)>;

        device_io(std::nullptr_t);
        explicit device_io(audio::device const &);

        ~device_io();

        device_io(device_io const &) = default;
        device_io(device_io &&) = default;
        device_io &operator=(device_io const &) = default;
        device_io &operator=(device_io &&) = default;

        void set_device(audio::device const device);
        audio::device device() const;
        bool is_running() const;
        void set_render_callback(render_f const &callback);
        void set_maximum_frames_per_slice(UInt32 const frames);
        UInt32 maximum_frames_per_slice() const;

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
