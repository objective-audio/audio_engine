//
//  yas_audio_graph.h
//

#pragma once

#include <map>
#include <unordered_set>
#include "yas_audio_graph_protocol.h"
#include "yas_audio_ptr.h"
#include "yas_audio_types.h"

namespace yas::audio {
struct graph final : interruptable_graph {
    virtual ~graph();

    void add_io(io_ptr const &);
    void remove_io(io_ptr const &);

    void start();
    void stop();
    bool is_running() const;

    uint8_t key() const;

   private:
    uint8_t _key;
    bool _running = false;
    mutable std::recursive_mutex _mutex;

    std::unordered_set<io_ptr> _ios;

    explicit graph(uint8_t const key);

    void _prepare(graph_ptr const &);

    void start_all_ios() override;
    void stop_all_ios() override;

   public:
    static graph_ptr make_shared();
};
}  // namespace yas::audio
