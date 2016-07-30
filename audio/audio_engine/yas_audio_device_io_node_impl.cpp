//
//  yas_audio_device_io_node_impl.cpp
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <iostream>
#include "yas_audio_device.h"
#include "yas_audio_device_io.h"
#include "yas_audio_graph.h"
#include "yas_audio_tap_node.h"
#include "yas_audio_time.h"
#include "yas_result.h"

using namespace yas;

struct audio::device_io_node::impl::core {
    audio::node _node = {{.input_bus_count = 1, .output_bus_count = 1}};
    audio::device_io device_io = nullptr;
    audio::node::observer_t _connections_observer;

    core() {
    }

    ~core() = default;

    void set_device(audio::device const &device) {
        _device = device;
        if (device_io) {
            device_io.set_device(device);
        }
    }

    audio::device device() const {
        return _device;
    }

   private:
    audio::device _device = nullptr;
};

audio::device_io_node::impl::impl() : _core(std::make_unique<core>()) {
}

audio::device_io_node::impl::~impl() = default;

void audio::device_io_node::impl::prepare(device_io_node const &device_io_node, audio::device const &device) {
    set_device(device ?: device::default_output_device());

    auto weak_node = to_weak(device_io_node);

    _core->_node.set_render_handler(
        [weak_node](audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when) {
            if (auto device_io_node = weak_node.lock()) {
                if (auto const &device_io = device_io_node.impl_ptr<impl>()->_core->device_io) {
                    auto &input_buffer = device_io.input_buffer_on_render();
                    if (input_buffer && input_buffer.format() == buffer.format()) {
                        buffer.copy_from(input_buffer);
                    }
                }
            }
        });

    _core->_connections_observer =
        _core->_node.subject().make_observer(audio::node::method::update_connections, [weak_node](auto const &) {
            if (auto device_io_node = weak_node.lock()) {
                device_io_node.impl_ptr<impl>()->update_device_io_connections();
            }
        });
}

#warning todo update_connectionsにリネームしたい
void audio::device_io_node::impl::update_device_io_connections() {
    auto &device_io = _core->device_io;
    if (!device_io) {
        return;
    }

    if (!_validate_connections()) {
        device_io.set_render_callback(nullptr);
        return;
    }

    auto weak_node = to_weak(cast<device_io_node>());
    auto weak_device_io = to_weak(device_io);

    auto render_function = [weak_node, weak_device_io](auto args) {
        if (auto node = weak_node.lock()) {
            if (auto kernel = node.impl_ptr<impl>()->node().impl_ptr<audio::node::impl>()->kernel_cast()) {
                if (args.output_buffer) {
                    auto const connections = kernel.input_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto source_node = connection.source_node()) {
                            if (connection.format() == source_node.output_format(connection.source_bus())) {
                                source_node.render(args.output_buffer, connection.source_bus(), args.when);
                            }
                        }
                    }
                }

                if (auto const device_io = weak_device_io.lock()) {
                    auto const connections = kernel.output_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto destination_node = connection.destination_node()) {
                            if (auto tap_node = yas::cast<input_tap_node>(destination_node)) {
                                auto input_buffer = device_io.input_buffer_on_render();
                                auto const &input_time = device_io.input_time_on_render();
                                if (input_buffer && input_time) {
                                    if (connection.format() ==
                                        destination_node.input_format(connection.destination_bus())) {
                                        tap_node.render(input_buffer, 0, input_time);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    };

    device_io.set_render_callback(std::move(render_function));
}

bool audio::device_io_node::impl::_validate_connections() const {
    if (auto const &device_io = _core->device_io) {
        auto &input_connections = node().impl_ptr<audio::node::impl>()->input_connections();
        if (input_connections.size() > 0) {
            auto const connections = lock_values(input_connections);
            if (connections.count(0) > 0) {
                auto const &connection = connections.at(0);
                auto const &connection_format = connection.format();
                auto const &device_format = device_io.device().output_format();
                if (connection_format != device_format) {
                    std::cout << __PRETTY_FUNCTION__ << " : output device io format is not match." << std::endl;
                    return false;
                }
            }
        }

        auto &output_connections = node().impl_ptr<audio::node::impl>()->output_connections();
        if (output_connections.size() > 0) {
            auto const connections = lock_values(output_connections);
            if (connections.count(0) > 0) {
                auto const &connection = connections.at(0);
                auto const &connection_format = connection.format();
                auto const &device_format = device_io.device().input_format();
                if (connection_format != device_format) {
                    std::cout << __PRETTY_FUNCTION__ << " : input device io format is not match." << std::endl;
                    return false;
                }
            }
        }
    }

    return true;
}

void audio::device_io_node::impl::add_device_io() {
    _core->device_io = audio::device_io{_core->device()};
}

void audio::device_io_node::impl::remove_device_io() {
    _core->device_io = nullptr;
}

audio::device_io &audio::device_io_node::impl::device_io() const {
    return _core->device_io;
}

void audio::device_io_node::impl::set_device(audio::device const &device) {
    _core->set_device(device);
}

audio::device audio::device_io_node::impl::device() const {
    return _core->device();
}

audio::node const &audio::device_io_node::impl::node() const {
    return _core->_node;
}

audio::node &audio::device_io_node::impl::node() {
    return _core->_node;
}

#endif
