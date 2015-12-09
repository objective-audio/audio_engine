//
//  yas_audio_graph.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit.h"
#include "yas_result.h"
#include "yas_base.h"
#include <memory>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device_io.h"
#endif

namespace yas {
namespace audio {
    class graph : public base {
        using super_class = base;

       public:
        class impl;

        graph();
        graph(std::nullptr_t);
        ~graph();

        graph(const graph &) = default;
        graph(graph &&) = default;
        graph &operator=(const graph &) = default;
        graph &operator=(graph &&) = default;

        void add_audio_unit(unit &audio_unit);
        void remove_audio_unit(unit &audio_unit);
        void remove_all_units();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void add_audio_device_io(audio::device_io &);
        void remove_audio_device_io(audio::device_io &);
#endif

        void start();
        void stop();
        bool is_running() const;

        // render thread
        static void audio_unit_render(render_parameters &render_parameters);
    };
}
}
