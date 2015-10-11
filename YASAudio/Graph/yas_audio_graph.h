//
//  yas_audio_graph.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit.h"
#include "yas_result.h"
#include "yas_weak.h"
#include <memory>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device_io.h"
#endif

namespace yas
{
    class audio_graph
    {
       public:
        audio_graph(std::nullptr_t n = nullptr);

        ~audio_graph() = default;

        audio_graph(const audio_graph &) = default;
        audio_graph(audio_graph &&) = default;
        audio_graph &operator=(const audio_graph &) = default;
        audio_graph &operator=(audio_graph &&) = default;

        bool operator==(const audio_graph &) const;
        bool operator!=(const audio_graph &) const;

        explicit operator bool() const;

        void prepare();

        void add_audio_unit(audio_unit &audio_unit);
        void remove_audio_unit(audio_unit &audio_unit);
        void remove_all_units();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void add_audio_device_io(audio_device_io &audio_device_io);
        void remove_audio_device_io(audio_device_io &audio_device_io);
#endif

        void start();
        void stop();
        bool is_running() const;

        // render thread
        static void audio_unit_render(render_parameters &render_parameters);

       private:
        class impl;
        std::shared_ptr<impl> _impl;

        explicit audio_graph(const UInt8 key);
        explicit audio_graph(const std::shared_ptr<audio_graph::impl> &);

       public:
        using weak = weak<audio_graph, audio_graph::impl>;
        friend weak;
    };
}
