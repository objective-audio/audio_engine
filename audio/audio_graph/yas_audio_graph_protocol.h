//
//  yas_audio_graph_protocol.h
//

#pragma once

namespace yas::audio {
struct interruptable_graph {
    virtual void start_all_ios() = 0;
    virtual void stop_all_ios() = 0;
};
}  // namespace yas::audio
