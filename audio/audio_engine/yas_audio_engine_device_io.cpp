//
//  yas_audio_device_io.cpp
//

#include "yas_audio_engine_device_io.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <cpp_utils/yas_result.h>
#include <iostream>
#include "yas_audio_device.h"
#include "yas_audio_device_io.h"
#include "yas_audio_engine_tap.h"
#include "yas_audio_graph.h"
#include "yas_audio_time.h"

using namespace yas;

#pragma mark - core

struct audio::engine::device_io::core {
    audio::device_io_ptr _device_io = nullptr;

    void set_device(std::optional<audio::device_ptr> const &device) {
        this->_device = device;
        if (this->_device_io) {
            this->_device_io->set_device(device);
        }
    }

    std::optional<audio::device_ptr> const &device() {
        return this->_device;
    }

   private:
    std::optional<audio::device_ptr> _device = std::nullopt;
};

#pragma mark - audio::engine::device_io

audio::engine::device_io::device_io() : _core(std::make_unique<core>()) {
}

audio::engine::device_io::~device_io() = default;

void audio::engine::device_io::set_device(std::optional<audio::device_ptr> const &device) {
    this->_core->set_device(device);
}

std::optional<audio::device_ptr> const &audio::engine::device_io::device() const {
    return this->_core->device();
}

audio::engine::node_ptr const &audio::engine::device_io::node() const {
    return this->_node;
}

audio::engine::manageable_device_io_ptr audio::engine::device_io::manageable() {
    return std::dynamic_pointer_cast<manageable_device_io>(this->_weak_engine_device_io.lock());
}

void audio::engine::device_io::add_raw_device_io() {
    this->_core->_device_io = audio::device_io::make_shared(this->_core->device());
}

void audio::engine::device_io::remove_raw_device_io() {
    this->_core->_device_io = nullptr;
}

audio::device_io_ptr const &audio::engine::device_io::raw_device_io() {
    return this->_core->_device_io;
}

void audio::engine::device_io::_prepare(device_io_ptr const &shared) {
    this->_weak_engine_device_io = to_weak(shared);

    this->set_device(device::default_output_device());

    this->_node->set_render_handler([weak_engine_device_io = this->_weak_engine_device_io](auto args) {
        auto &buffer = args.buffer;

        if (auto engine_device_io = weak_engine_device_io.lock()) {
            if (auto const &device_io = engine_device_io->raw_device_io()) {
                auto const &input_buffer_opt = device_io->input_buffer_on_render();
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
                                      .perform([weak_engine_device_io = this->_weak_engine_device_io](auto const &) {
                                          if (auto engine_device_io = weak_engine_device_io.lock()) {
                                              engine_device_io->_update_device_io_connections();
                                          }
                                      })
                                      .end();
}

void audio::engine::device_io::_update_device_io_connections() {
    auto &device_io = this->_core->_device_io;
    if (!device_io) {
        return;
    }

    if (!this->_validate_connections()) {
        device_io->set_render_handler(nullptr);
        return;
    }

    auto weak_device_io = to_weak(device_io);

    auto render_handler = [weak_engine_device_io = this->_weak_engine_device_io, weak_device_io](auto args) {
        if (auto engine_device_io = weak_engine_device_io.lock()) {
            if (auto kernel = engine_device_io->node()->kernel()) {
                auto const connections = kernel->input_connections();
                if (connections.count(0) > 0) {
                    auto const &connection = connections.at(0);
                    if (auto src_node = connection->source_node();
                        src_node && connection->format == src_node->output_format(connection->source_bus)) {
                        if (auto const when = args.when) {
                            src_node->render(
                                {.buffer = *args.output_buffer, .bus_idx = connection->source_bus, .when = *args.when});
                        }
                    }
                }

                if (auto device_io = weak_device_io.lock()) {
                    auto const connections = kernel->output_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto dst_node = connection->destination_node();
                            dst_node && dst_node->is_input_renderable()) {
                            auto const &input_buffer = device_io->input_buffer_on_render();
                            auto const &input_time = device_io->input_time_on_render();
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

    device_io->set_render_handler(std::move(render_handler));
}

bool audio::engine::device_io::_validate_connections() {
    if (auto const &device_io = this->_core->_device_io) {
        auto &input_connections = this->_node->manageable()->input_connections();
        if (input_connections.size() > 0) {
            auto const connections = lock_values(input_connections);
            if (connections.count(0) > 0) {
                auto const &connection = connections.at(0);
                auto const &connection_format = connection->format;
                auto const &device_opt = device_io->device();
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
                auto const &device_opt = device_io->device();
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

audio::engine::device_io_ptr audio::engine::device_io::make_shared() {
    auto shared = device_io_ptr(new audio::engine::device_io{});
    shared->_prepare(shared);
    return shared;
}

#endif
