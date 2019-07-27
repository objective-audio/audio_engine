//
//  yas_audio_engine_device_io.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <chaining/yas_chaining_umbrella.h>
#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_device_io_protocol.h"
#include "yas_audio_engine_node.h"

namespace yas::audio {
class device;
}

namespace yas::audio::engine {
struct device_io : manageable_device_io, std::enable_shared_from_this<device_io> {
    class core;

    virtual ~device_io();

    void set_device(std::shared_ptr<audio::device> const &device);
    std::shared_ptr<audio::device> device() const;

    audio::engine::node const &node() const;
    audio::engine::node &node();

    std::shared_ptr<manageable_device_io> manageable();

   private:
    std::shared_ptr<audio::engine::node> _node = make_node({.input_bus_count = 1, .output_bus_count = 1});
    chaining::any_observer_ptr _connections_observer = nullptr;
    std::unique_ptr<core> _core;

    device_io();

    device_io(device_io &&) = delete;
    device_io &operator=(device_io &&) = delete;
    device_io(device_io const &) = delete;
    device_io &operator=(device_io const &) = delete;

    void add_raw_device_io() override;
    void remove_raw_device_io() override;
    std::shared_ptr<audio::device_io> &raw_device_io() override;

    void _prepare();
    void _update_device_io_connections();
    bool _validate_connections();

public:
    static std::shared_ptr<device_io> make_shared();
};
}  // namespace yas::audio::engine

#endif
