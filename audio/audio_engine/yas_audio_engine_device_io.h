//
//  yas_audio_engine_device_io.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_engine_device_io_protocol.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct device_io : manageable_device_io {
    class core;

    virtual ~device_io();

    void set_device(std::optional<audio::mac_device_ptr> const &device);
    std::optional<audio::mac_device_ptr> const &device() const;

    audio::engine::node_ptr const &node() const;

    manageable_device_io_ptr manageable();

   private:
    std::weak_ptr<device_io> _weak_engine_device_io;
    audio::engine::node_ptr _node = node::make_shared({.input_bus_count = 1, .output_bus_count = 1});
    chaining::any_observer_ptr _connections_observer = nullptr;
    std::unique_ptr<core> _core;

    device_io();

    device_io(device_io &&) = delete;
    device_io &operator=(device_io &&) = delete;
    device_io(device_io const &) = delete;
    device_io &operator=(device_io const &) = delete;

    void add_raw_device_io() override;
    void remove_raw_device_io() override;
    audio::device_io_ptr const &raw_device_io() override;

    void _prepare(device_io_ptr const &);
    void _update_device_io_connections();
    bool _validate_connections();

   public:
    static device_io_ptr make_shared();
};
}  // namespace yas::audio::engine

#endif
