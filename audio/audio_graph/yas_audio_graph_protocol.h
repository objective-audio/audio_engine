//
//  yas_audio_graph_protocol.h
//

#pragma once

namespace yas::audio {
struct interruptable_graph {
    virtual ~interruptable_graph() = default;

    virtual void start_all_ios() = 0;
    virtual void stop_all_ios() = 0;
};

using interruptable_graph_ptr = std::shared_ptr<interruptable_graph>;
}  // namespace yas::audio
