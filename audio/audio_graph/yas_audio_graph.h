//
//  yas_audio_graph.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_types.h"

namespace yas::audio {
class unit;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
class device_io;
#endif

class graph final : public base {
   public:
    class impl;

    graph();
    graph(std::nullptr_t);

    virtual ~graph();

    void add_unit(audio::unit &);
    void remove_unit(audio::unit &);
    void remove_all_units();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void add_audio_device_io(audio::device_io &);
    void remove_audio_device_io(audio::device_io &);
#endif

    void start();
    void stop();
    bool is_running() const;

    // render thread
    static void unit_render(render_parameters &render_parameters);
};
}  // namespace yas::audio
