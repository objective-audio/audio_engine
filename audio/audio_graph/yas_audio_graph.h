//
//  yas_audio_graph.h
//

#pragma once

#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class unit;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class device_io;
#endif

    class graph : public base {
       public:
        class impl;

        graph();
        graph(std::nullptr_t);

        virtual ~graph() final;

        void add_unit(unit &audio_unit);
        void remove_unit(unit &audio_unit);
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
