//
//  yas_audio_engine_io.cpp
//

#include "yas_audio_engine_io.h"

#include <cpp_utils/yas_result.h>
#include <iostream>
#include "yas_audio_engine_tap.h"
#include "yas_audio_graph.h"
#include "yas_audio_io.h"
#include "yas_audio_time.h"

using namespace yas;

#pragma mark - core

struct audio::engine::io::core {
    audio::io_ptr _io = nullptr;

    void set_device(std::optional<audio::io_device_ptr> const &device) {
        this->_device = device;
        if (this->_io) {
            this->_io->set_device(device);
        }
    }

    std::optional<audio::io_device_ptr> const &device() {
        return this->_device;
    }

   private:
    std::optional<audio::io_device_ptr> _device = std::nullopt;
};

#pragma mark - audio::engine::io

audio::engine::io::io() : _core(std::make_unique<core>()) {
}

audio::engine::io::~io() = default;

void audio::engine::io::set_device(std::optional<audio::io_device_ptr> const &device) {
    this->_core->set_device(device);
}

std::optional<audio::io_device_ptr> const &audio::engine::io::device() const {
    return this->_core->device();
}

audio::engine::node_ptr const &audio::engine::io::node() const {
    return this->_node;
}

audio::engine::manageable_io_ptr audio::engine::io::manageable() {
    return std::dynamic_pointer_cast<manageable_io>(this->_weak_engine_io.lock());
}

void audio::engine::io::add_raw_io() {
    this->_core->_io = audio::io::make_shared(this->_core->device());
}

void audio::engine::io::remove_raw_io() {
    this->_core->_io = nullptr;
}

audio::io_ptr const &audio::engine::io::raw_io() {
    return this->_core->_io;
}

void audio::engine::io::_prepare(io_ptr const &shared) {
    this->_weak_engine_io = to_weak(shared);

    this->_node->set_render_handler([weak_engine_io = this->_weak_engine_io](auto args) {
        auto &buffer = args.buffer;

        if (auto engine_io = weak_engine_io.lock()) {
            if (auto const &raw_io = engine_io->raw_io()) {
                auto const &input_buffer_opt = raw_io->input_buffer_on_render();
                if (input_buffer_opt) {
                    auto const &input_buffer = *input_buffer_opt;
                    if (input_buffer->format() == buffer.format()) {
                        buffer.copy_from(*input_buffer);
                    }
                }
            }
        }
    });

    this->_connections_observer = this->_node->chain(node::method::update_connections)
                                      .perform([weak_engine_io = this->_weak_engine_io](auto const &) {
                                          if (auto engine_io = weak_engine_io.lock()) {
                                              engine_io->_update_io_connections();
                                          }
                                      })
                                      .end();
}

void audio::engine::io::_update_io_connections() {
    auto &raw_io = this->_core->_io;
    if (!raw_io) {
        return;
    }

    if (!this->_validate_connections()) {
        raw_io->set_render_handler(nullptr);
        return;
    }

    auto weak_io = to_weak(raw_io);

    auto render_handler = [weak_engine_io = this->_weak_engine_io, weak_io](auto args) {
        if (auto engine_io = weak_engine_io.lock()) {
            if (auto kernel = engine_io->node()->kernel()) {
                auto const connections = kernel->input_connections();
                if (connections.count(0) > 0) {
                    auto const &connection = connections.at(0);
                    if (auto src_node = connection->source_node();
                        src_node && connection->format == src_node->output_format(connection->source_bus)) {
                        if (auto const when = args.when) {
                            src_node->render({.buffer = **args.output_buffer,
                                              .bus_idx = connection->source_bus,
                                              .when = *args.when});
                        }
                    }
                }

                if (auto io = weak_io.lock()) {
                    auto const connections = kernel->output_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto dst_node = connection->destination_node();
                            dst_node && dst_node->is_input_renderable()) {
                            auto const &input_buffer = io->input_buffer_on_render();
                            auto const &input_time = io->input_time_on_render();
                            if (input_buffer && input_time) {
                                if (connection->format == dst_node->input_format(connection->destination_bus)) {
                                    dst_node->render({.buffer = **input_buffer, .bus_idx = 0, .when = **input_time});
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    raw_io->set_render_handler(std::move(render_handler));
}

bool audio::engine::io::_validate_connections() {
    if (auto const &raw_io = this->_core->_io) {
        auto &input_connections = this->_node->manageable()->input_connections();
        if (input_connections.size() > 0) {
            auto const connections = lock_values(input_connections);
            if (connections.count(0) > 0) {
                auto const &connection = connections.at(0);
                auto const &connection_format = connection->format;
                auto const &device_opt = raw_io->device();
                if (!device_opt) {
                    std::cout << __PRETTY_FUNCTION__ << " : output device is null." << std::endl;
                    return false;
                }
                auto const &device = *device_opt;
                if (connection_format != device->output_format()) {
                    std::cout << __PRETTY_FUNCTION__ << " : output device io format is not match." << std::endl;
                    return false;
                }
            }
        }

        auto &output_connections = this->_node->manageable()->output_connections();
        if (output_connections.size() > 0) {
            auto const connections = lock_values(output_connections);
            if (connections.count(0) > 0) {
                auto const &connection = connections.at(0);
                auto const &connection_format = connection->format;
                auto const &device_opt = raw_io->device();
                if (!device_opt) {
                    std::cout << __PRETTY_FUNCTION__ << " : output device is null." << std::endl;
                    return false;
                }
                auto const &device = *device_opt;
                if (connection_format != device->input_format()) {
                    std::cout << __PRETTY_FUNCTION__ << " : input device io format is not match." << std::endl;
                    return false;
                }
            }
        }
    }

    return true;
}

audio::engine::io_ptr audio::engine::io::make_shared() {
    auto shared = io_ptr(new audio::engine::io{});
    shared->_prepare(shared);
    return shared;
}
