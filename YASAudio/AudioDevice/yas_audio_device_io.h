//
//  yas_audio_device_io.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_types.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_device.h"
#include <functional>
#include <memory>

namespace yas
{
    class audio_device_io
    {
       public:
        using render_f = std::function<void(audio_pcm_buffer &output_buffer, const audio_time &when)>;

        static audio_device_io_sptr create();
        static audio_device_io_sptr create(const audio_device_sptr &audio_device);

        ~audio_device_io();

        void set_device(const audio_device_sptr device);
        audio_device_sptr device() const;
        bool is_running() const;
        void set_render_callback(const render_f &callback);
        void set_maximum_frames_per_slice(const UInt32 frames);
        UInt32 maximum_frames_per_slice() const;

        void start();
        void stop();

        const audio_pcm_buffer &input_buffer_on_render() const;
        const audio_time &input_time_on_render() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        audio_device_io();

        audio_device_io(const audio_device_io &) = delete;
        audio_device_io(audio_device_io &&) = delete;
        audio_device_io &operator=(const audio_device_io &) = delete;
        audio_device_io &operator=(audio_device_io &&) = delete;

        void _initialize();
        void _uninitialize();
    };
}

#endif
