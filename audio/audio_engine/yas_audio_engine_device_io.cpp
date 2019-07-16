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
    std::shared_ptr<audio::device_io> _device_io = nullptr;

    void set_device(std::shared_ptr<audio::device> const &device) {
        this->_device = device;
        if (this->_device_io) {
            this->_device_io->set_device(device);
        }
    }

    std::shared_ptr<audio::device> device() {
        return this->_device;
    }

   private:
    std::shared_ptr<audio::device> _device = nullptr;
};

#pragma mark - audio::engine::device_io::impl

struct audio::engine::device_io::impl final {
    std::shared_ptr<audio::engine::node> _node = make_node({.input_bus_count = 1, .output_bus_count = 1});
    chaining::any_observer_ptr _connections_observer = nullptr;

    void prepare(engine::device_io &engine_device_io) {
        this->set_device(device::default_output_device());

        auto weak_engine_device_io = to_weak(engine_device_io.shared_from_this());

        this->_node->set_render_handler([weak_engine_device_io](auto args) {
            auto &buffer = args.buffer;

            if (auto engine_device_io = weak_engine_device_io.lock();
                auto &device_io = engine_device_io->_impl->raw_device_io()) {
                auto &input_buffer = device_io->input_buffer_on_render();
                if (input_buffer && input_buffer->format() == buffer.format()) {
                    buffer.copy_from(*input_buffer);
                }
            }
        });

        this->_connections_observer =
            this->_node->chain(node::method::update_connections)
                .perform([weak_engine_device_io](auto const &) {
                    if (auto engine_device_io = weak_engine_device_io.lock()) {
                        engine_device_io->_impl->_update_device_io_connections(*engine_device_io);
                    }
                })
                .end();
    }

    void add_raw_device_io() {
        this->_core._device_io = std::make_shared<audio::device_io>(this->_core.device());
    }

    void remove_raw_device_io() {
        this->_core._device_io = nullptr;
    }

    std::shared_ptr<audio::device_io> &raw_device_io() {
        return this->_core._device_io;
    }

    void set_device(std::shared_ptr<audio::device> const &device) {
        this->_core.set_device(device);
    }

    std::shared_ptr<audio::device> device() {
        return this->_core.device();
    }

   private:
    core _core;

    void _update_device_io_connections(engine::device_io &engine_device_io) {
        auto &device_io = this->_core._device_io;
        if (!device_io) {
            return;
        }

        if (!this->_validate_connections()) {
            device_io->set_render_handler(nullptr);
            return;
        }

        auto weak_engine_device_io = to_weak(engine_device_io.shared_from_this());
        auto weak_device_io = to_weak(device_io);

        auto render_handler = [weak_engine_device_io, weak_device_io](auto args) {
            if (auto engine_device_io = weak_engine_device_io.lock()) {
                if (auto kernel = engine_device_io->node().kernel()) {
                    auto const connections = kernel->input_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto src_node = connection.source_node();
                            src_node && connection.format() == src_node->output_format(connection.source_bus())) {
                            if (auto const when = args.when) {
                                src_node->render({.buffer = *args.output_buffer,
                                                  .bus_idx = connection.source_bus(),
                                                  .when = *args.when});
                            }
                        }
                    }

                    if (auto device_io = weak_device_io.lock()) {
                        auto const connections = kernel->output_connections();
                        if (connections.count(0) > 0) {
                            auto const &connection = connections.at(0);
                            if (auto dst_node = connection.destination_node();
                                dst_node && dst_node->is_input_renderable()) {
                                auto &input_buffer = device_io->input_buffer_on_render();
                                auto const &input_time = device_io->input_time_on_render();
                                if (input_buffer && input_time) {
                                    if (connection.format() == dst_node->input_format(connection.destination_bus())) {
                                        dst_node->render({.buffer = *input_buffer, .bus_idx = 0, .when = *input_time});
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

    bool _validate_connections() {
        if (auto const &device_io = this->_core._device_io) {
            auto &input_connections = this->_node->input_connections();
            if (input_connections.size() > 0) {
                auto const connections = lock_values(input_connections);
                if (connections.count(0) > 0) {
                    auto const &connection = connections.at(0);
                    auto const &connection_format = connection.format();
                    auto const &device_format = device_io->device()->output_format();
                    if (connection_format != device_format) {
                        std::cout << __PRETTY_FUNCTION__ << " : output device io format is not match." << std::endl;
                        return false;
                    }
                }
            }

            auto &output_connections = this->_node->output_connections();
            if (output_connections.size() > 0) {
                auto const connections = lock_values(output_connections);
                if (connections.count(0) > 0) {
                    auto const &connection = connections.at(0);
                    auto const &connection_format = connection.format();
                    auto const &device_format = device_io->device()->input_format();
                    if (connection_format != device_format) {
                        std::cout << __PRETTY_FUNCTION__ << " : input device io format is not match." << std::endl;
                        return false;
                    }
                }
            }
        }

        return true;
    }
};

#pragma mark - audio::engine::device_io

audio::engine::device_io::device_io() : _impl(std::make_unique<impl>()) {
}

audio::engine::device_io::~device_io() = default;

void audio::engine::device_io::set_device(std::shared_ptr<audio::device> const &device) {
    this->_impl->set_device(device);
}

std::shared_ptr<audio::device> audio::engine::device_io::device() const {
    return this->_impl->device();
}

audio::engine::node const &audio::engine::device_io::node() const {
    return *this->_impl->_node;
}

audio::engine::node &audio::engine::device_io::node() {
    return *this->_impl->_node;
}

void audio::engine::device_io::add_raw_device_io() {
    this->_impl->add_raw_device_io();
}

void audio::engine::device_io::remove_raw_device_io() {
    this->_impl->remove_raw_device_io();
}

std::shared_ptr<audio::device_io> &audio::engine::device_io::raw_device_io() {
    return this->_impl->raw_device_io();
}

void audio::engine::device_io::_prepare() {
    this->_impl->prepare(*this);
}

namespace yas::audio::engine {
struct device_io_factory : device_io {
    void prepare() {
        this->_prepare();
    }
};
};  // namespace yas::audio::engine

std::shared_ptr<audio::engine::device_io> audio::engine::make_device_io() {
    auto shared = std::make_shared<audio::engine::device_io_factory>();
    shared->prepare();
    return shared;
}

#endif
