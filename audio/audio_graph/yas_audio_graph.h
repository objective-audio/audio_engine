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

struct graph : base, std::enable_shared_from_this<graph> {
    class impl;

    graph(std::nullptr_t);

    virtual ~graph();

    void add_unit(std::shared_ptr<audio::unit> &);
    void remove_unit(std::shared_ptr<audio::unit> &);
    void remove_all_units();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void add_audio_device_io(std::shared_ptr<device_io> &);
    void remove_audio_device_io(std::shared_ptr<device_io> &);
#endif

    void start();
    void stop();
    bool is_running() const;

    // render thread
    static void unit_render(render_parameters &render_parameters);

   protected:
    graph();

    void prepare();
};

std::shared_ptr<graph> make_graph();
}  // namespace yas::audio
