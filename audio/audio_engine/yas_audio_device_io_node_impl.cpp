//
//  yas_audio_device_io_node_impl.cpp
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <iostream>
#include "yas_audio_device_io.h"
#include "yas_audio_graph.h"
#include "yas_audio_tap_node.h"
#include "yas_audio_time.h"

using namespace yas;

class audio::device_io_node::impl::core {
   public:
    audio::device_io device_io;

    core() : _device(nullptr), device_io(nullptr) {
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
    audio::device _device;
};

audio::device_io_node::impl::impl() : node::impl(), _core(std::make_unique<core>()) {
}

audio::device_io_node::impl::~impl() = default;

void audio::device_io_node::impl::prepare(device_io_node const &node, audio::device const &device) {
    set_device(device ?: device::default_output_device());
}

UInt32 audio::device_io_node::impl::input_bus_count() const {
    return 1;
}

UInt32 audio::device_io_node::impl::output_bus_count() const {
    return 1;
}

void audio::device_io_node::impl::update_connections() {
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

    auto render_function = [weak_node, weak_device_io](pcm_buffer &output_buffer, time const &when) {
        if (auto node = weak_node.lock()) {
            if (auto kernel = node.impl_ptr<impl>()->kernel_cast()) {
                if (output_buffer) {
                    auto const connections = kernel->input_connections();
                    if (connections.count(0) > 0) {
                        auto const &connection = connections.at(0);
                        if (auto source_node = connection.source_node()) {
                            if (connection.format() == source_node.output_format(connection.source_bus())) {
                                source_node.render(output_buffer, connection.source_bus(), when);
                            }
                        }
                    }
                }

                if (auto const device_io = weak_device_io.lock()) {
                    auto const connections = kernel->output_connections();
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

    device_io.set_render_callback(render_function);
}

bool audio::device_io_node::impl::_validate_connections() const {
    if (auto const &device_io = _core->device_io) {
        if (input_connections().size() > 0) {
            auto const connections = yas::lock_values(input_connections());
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

        if (output_connections().size() > 0) {
            auto const connections = yas::lock_values(output_connections());
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

void audio::device_io_node::impl::render(pcm_buffer &buffer, const UInt32 bus_idx, time const &when) {
    node::impl::render(buffer, bus_idx, when);

    if (auto const &device_io = _core->device_io) {
        auto &input_buffer = device_io.input_buffer_on_render();
        if (input_buffer && input_buffer.format() == buffer.format()) {
            buffer.copy_from(input_buffer);
        }
    }
}

#endif
