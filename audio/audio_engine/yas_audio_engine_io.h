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
    audio::engine::node_ptr _node;
    audio::io_ptr _raw_io;
    chaining::any_observer_ptr _connections_observer;

    io(audio::io_ptr const &);

    io(io &&) = delete;
    io &operator=(io &&) = delete;
    io(io const &) = delete;
    io &operator=(io const &) = delete;

    void _prepare(io_ptr const &);
    void _update_io_connections();
    bool _validate_connections();
};
}  // namespace yas::audio::engine
