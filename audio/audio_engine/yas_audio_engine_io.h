//
//  yas_audio_engine_io.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_engine_io_protocol.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_engine_ptr.h"
#include "yas_audio_io_device.h"

namespace yas::audio::engine {
struct io : manageable_io {
    virtual ~io();

    void set_device(std::optional<audio::io_device_ptr> const &device);
    std::optional<audio::io_device_ptr> const &device() const;

    audio::engine::node_ptr const &node() const;

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain();

    static io_ptr make_shared();

   private:
    std::weak_ptr<io> _weak_engine_io;
    audio::engine::node_ptr _node = node::make_shared({.input_bus_count = 1, .output_bus_count = 1});
    std::optional<chaining::any_observer_ptr> _connections_observer = std::nullopt;
    std::optional<audio::io_device_ptr> _device = std::nullopt;
    std::optional<audio::io_ptr> _raw_io = std::nullopt;
    bool _running = false;
    chaining::notifier_ptr<io_device::method> _notifier;
    std::optional<chaining::any_observer_ptr> _io_observer = std::nullopt;

    io();

    io(io &&) = delete;
    io &operator=(io &&) = delete;
    io(io const &) = delete;
    io &operator=(io const &) = delete;

    audio::io_ptr const &add_raw_io() override;
    void remove_raw_io() override;
    std::optional<audio::io_ptr> const &raw_io() override;
    void start() override;
    void stop() override;

    void _prepare(io_ptr const &);
    void _update_io_connections();
    bool _validate_connections();
    void _start_raw_io();
    void _stop_raw_io();
};
}  // namespace yas::audio::engine
