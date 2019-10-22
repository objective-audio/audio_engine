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

    void add_unit(audio::unit_ptr const &);
    void remove_unit(audio::unit_ptr const &);
    void remove_all_units();

    void add_io(io_ptr const &);
    void remove_io(io_ptr const &);
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void add_audio_device_io(device_io_ptr const &);
    void remove_audio_device_io(device_io_ptr const &);
#endif

    void start();
    void stop();
    bool is_running() const;

    uint8_t key() const;

    // render thread
    static void unit_render(render_parameters &render_parameters);

   private:
    uint8_t _key;
    bool _running = false;
    mutable std::recursive_mutex _mutex;
    std::map<uint16_t, unit_ptr> _units;
    std::map<uint16_t, unit_ptr> _io_units;

    std::unordered_set<io_ptr> _ios;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::unordered_set<device_io_ptr> _device_ios;
#endif

    explicit graph(uint8_t const key);

    void _prepare(graph_ptr const &);

    void start_all_ios() override;
    void stop_all_ios() override;

    std::optional<uint16_t> _next_unit_key();
    unit_ptr _unit_for_key(uint16_t const key) const;
    void _add_unit_to_units(audio::unit_ptr const &unit);
    void _remove_unit_from_units(audio::unit_ptr const &unit);

   public:
    static graph_ptr make_shared();
};
}  // namespace yas::audio
