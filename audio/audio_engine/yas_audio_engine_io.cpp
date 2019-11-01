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

#pragma mark - audio::engine::io

audio::engine::io::io() = default;

audio::engine::io::~io() = default;

void audio::engine::io::set_device(std::optional<audio::io_device_ptr> const &device) {
    this->_device = device;

    if (this->_raw_io) {
        this->_raw_io.value()->set_device(device);
    }

    if (device) {
        this->_io_observer = device.value()->io_device_chain().send_to(this->_notifier).end();
    } else {
        this->_io_observer = std::nullopt;
    }
}

std::optional<audio::io_device_ptr> const &audio::engine::io::device() const {
    return this->_device;
}

audio::engine::node_ptr const &audio::engine::io::node() const {
    return this->_node;
}

audio::io_ptr const &audio::engine::io::add_raw_io() {
    if (!this->_raw_io) {
        this->_raw_io = audio::io::make_shared(this->device());
    }
    return this->_raw_io.value();
}

void audio::engine::io::remove_raw_io() {
    this->_raw_io = std::nullopt;
}

std::optional<audio::io_ptr> const &audio::engine::io::raw_io() {
    return this->_raw_io;
}

chaining::chain_unsync_t<audio::io_device::method> audio::engine::io::io_device_chain() {
    return this->_notifier->chain();
}

void audio::engine::io::_prepare(io_ptr const &shared) {
    this->_weak_engine_io = to_weak(shared);

    this->_node->set_render_handler([weak_engine_io = this->_weak_engine_io](auto args) {
        auto &buffer = args.buffer;

        if (auto engine_io = weak_engine_io.lock()) {
            if (auto const &raw_io = engine_io->raw_io()) {
                auto const &input_buffer_opt = raw_io.value()->input_buffer_on_render();
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
    auto const &raw_io_opt = this->_raw_io;
    if (!raw_io_opt) {
        return;
    }

    auto const &raw_io = raw_io_opt.value();

    if (!this->_validate_connections()) {
        raw_io->set_render_handler(std::nullopt);
        return;
    }

    auto weak_io = to_weak(raw_io);

    auto render_handler = [weak_engine_io = this->_weak_engine_io, weak_io](auto args) {
        if (auto engine_io = weak_engine_io.lock()) {
            if (auto const kernel_opt = engine_io->node()->kernel()) {
                auto const &kernel = kernel_opt.value();
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
    if (auto const &raw_io_opt = this->_raw_io) {
        auto const &raw_io = raw_io_opt.value();

        auto &input_connections = manageable_node::cast(this->_node)->input_connections();
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

        auto &output_connections = manageable_node::cast(this->_node)->output_connections();
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
