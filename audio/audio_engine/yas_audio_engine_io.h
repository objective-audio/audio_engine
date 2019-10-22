//
//  yas_audio_engine_io.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_engine_io_protocol.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct io : manageable_io {
    class core;

    virtual ~io();

    void set_device(std::optional<audio::io_device_ptr> const &device);
    std::optional<audio::io_device_ptr> const &device() const;

    audio::engine::node_ptr const &node() const;

    manageable_io_ptr manageable();

    static io_ptr make_shared();

   private:
    std::weak_ptr<io> _weak_engine_io;
    audio::engine::node_ptr _node = node::make_shared({.input_bus_count = 1, .output_bus_count = 1});
    chaining::any_observer_ptr _connections_observer = nullptr;
    std::unique_ptr<core> _core;

    io();

    io(io &&) = delete;
    io &operator=(io &&) = delete;
    io(io const &) = delete;
    io &operator=(io const &) = delete;

    void add_raw_io() override;
    void remove_raw_io() override;
    audio::io_ptr const &raw_io() override;

    void _prepare(io_ptr const &);
    void _update_device_io_connections();
    bool _validate_connections();
};
}  // namespace yas::audio::engine
