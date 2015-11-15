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

namespace yas
{
    class audio_pcm_buffer;
    class audio_time;

    class audio_device_io : public base
    {
        using super_class = base;

       public:
        using render_f = std::function<void(audio_pcm_buffer &output_buffer, const audio_time &when)>;

        audio_device_io(std::nullptr_t);
        explicit audio_device_io(const audio_device &device);

        ~audio_device_io();

        audio_device_io(const audio_device_io &) = default;
        audio_device_io(audio_device_io &&) = default;
        audio_device_io &operator=(const audio_device_io &) = default;
        audio_device_io &operator=(audio_device_io &&) = default;

        void set_device(const audio_device device) const;
        audio_device device() const;
        bool is_running() const;
        void set_render_callback(const render_f &callback) const;
        void set_maximum_frames_per_slice(const UInt32 frames) const;
        UInt32 maximum_frames_per_slice() const;

        void start() const;
        void stop() const;

        const audio_pcm_buffer &input_buffer_on_render() const;
        const audio_time &input_time_on_render() const;

       private:
        class kernel;
        class impl;

        void _initialize() const;
        void _uninitialize() const;
    };
}

#endif
