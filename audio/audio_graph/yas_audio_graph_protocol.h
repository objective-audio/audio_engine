//
//  yas_audio_graph_protocol.h
//

#pragma once

namespace yas::audio {
class interruptable_graph;
using interruptable_graph_ptr = std::shared_ptr<interruptable_graph>;

struct interruptable_graph {
    virtual ~interruptable_graph() = default;

    virtual void start_all_ios() = 0;
    virtual void stop_all_ios() = 0;

    static interruptable_graph_ptr cast(interruptable_graph_ptr const &graph) {
        return graph;
    }
};
}  // namespace yas::audio
