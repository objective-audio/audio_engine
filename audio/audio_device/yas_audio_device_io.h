//
//  yas_audio_device_io.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_types.h"
#include "yas_audio_device.h"
#include "yas_base.h"
#include <functional>
#include <memory>

namespace yas {
namespace audio {
    class pcm_buffer;
    class time;

    class device_io : public base {
        using super_class = base;

       public:
        using render_f = std::function<void(audio::pcm_buffer &output_buffer, const audio::time &when)>;

        device_io(std::nullptr_t);
        explicit device_io(const audio::device &);

        ~device_io();

        device_io(const device_io &) = default;
        device_io(device_io &&) = default;
        device_io &operator=(const device_io &) = default;
        device_io &operator=(device_io &&) = default;

        void set_device(const audio::device device);
        audio::device device() const;
        bool is_running() const;
        void set_render_callback(const render_f &callback);
        void set_maximum_frames_per_slice(const UInt32 frames);
        UInt32 maximum_frames_per_slice() const;

        void start() const;
        void stop() const;

        const audio::pcm_buffer &input_buffer_on_render() const;
        const audio::time &input_time_on_render() const;

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
