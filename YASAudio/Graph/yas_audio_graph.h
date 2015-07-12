//
//  yas_audio_graph.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit.h"
#include <memory>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device_io.h"
#endif

namespace yas
{
    class audio_graph;
    using audio_graph_ptr = std::shared_ptr<audio_graph>;

    class audio_graph
    {
       public:
        static audio_graph_ptr create();
        ~audio_graph();

        void add_audio_unit(audio_unit_ptr &audio_unit);
        void remove_audio_unit(audio_unit_ptr &audio_unit);
        void remove_all_units();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void add_audio_device_io(audio_device_io_ptr &audio_device_io);
        void remove_audio_device_io(audio_device_io_ptr &audio_device_io);
#endif

        void start();
        void stop();
        bool is_running() const;

        // render thread
        static void audio_unit_render(render_parameters &render_parameters);

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        explicit audio_graph(const UInt8 key);

        audio_graph(const audio_graph &) = delete;
        audio_graph(const audio_graph &&) = delete;
        audio_graph &operator=(const audio_graph &) = delete;
        audio_graph &operator=(const audio_graph &&) = delete;
    };
}
