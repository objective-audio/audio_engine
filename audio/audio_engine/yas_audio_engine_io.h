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

    audio::engine::node_ptr const &node() const;

    audio::io_ptr const &raw_io() override;

    static io_ptr make_shared(audio::io_ptr const &);

   private:
    std::weak_ptr<io> _weak_engine_io;
    audio::engine::node_ptr _node = node::make_shared({.input_bus_count = 1, .output_bus_count = 1});
    std::optional<chaining::any_observer_ptr> _connections_observer = std::nullopt;
    audio::io_ptr _raw_io;
    bool _running = false;
    chaining::notifier_ptr<io_device::method> _notifier;
    std::optional<chaining::any_observer_ptr> _io_observer = std::nullopt;

    io(audio::io_ptr const &);

    io(io &&) = delete;
    io &operator=(io &&) = delete;
    io(io const &) = delete;
    io &operator=(io const &) = delete;

    void start() override;
    void stop() override;

    void _prepare(io_ptr const &);
    void _update_io_connections();
    bool _validate_connections();
};
}  // namespace yas::audio::engine
