//
//  yas_audio_graph.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include <unordered_set>
#include "yas_audio_graph_protocol.h"
#include "yas_audio_types.h"

namespace yas::audio {
class unit;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
class device_io;
#endif

struct graph : std::enable_shared_from_this<graph>, interruptable_graph {
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

    uint8_t key() const;

    std::shared_ptr<interruptable_graph> interruptable();

    // render thread
    static void unit_render(render_parameters &render_parameters);

   private:
    uint8_t _key;
    bool _running = false;
    mutable std::recursive_mutex _mutex;
    std::map<uint16_t, std::shared_ptr<unit>> _units;
    std::map<uint16_t, std::shared_ptr<unit>> _io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::unordered_set<std::shared_ptr<device_io>> _device_ios;
#endif

    explicit graph(uint8_t const key);

    void _prepare();

    void start_all_ios() override;
    void stop_all_ios() override;

    std::optional<uint16_t> _next_unit_key();
    std::shared_ptr<unit> _unit_for_key(uint16_t const key) const;
    void _add_unit_to_units(std::shared_ptr<audio::unit> &unit);
    void _remove_unit_from_units(std::shared_ptr<audio::unit> &unit);

   public:
    static std::shared_ptr<graph> make_shared();
};
}  // namespace yas::audio
