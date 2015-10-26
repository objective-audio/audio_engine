//
//  yas_audio_device_io_node_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device_io.h"
#include "yas_audio_tap_node.h"
#include "yas_audio_time.h"
#include "yas_audio_graph.h"

using namespace yas;

class audio_device_io_node::impl::core
{
   public:
    weak<audio_device_io_node> weak_node;
    weak<audio_graph> weak_graph;
    audio_device_io device_io;

    core() : weak_node(), _device(nullptr), weak_graph(), device_io(nullptr)
    {
    }

    ~core() = default;

    void set_device(const audio_device &device)
    {
        _device = device;
        if (device_io) {
            device_io.set_device(device);
        }
    }

    audio_device device() const
    {
        return _device;
    }

   private:
    audio_device _device;
};

audio_device_io_node::impl::impl() : audio_node::impl(), _core(std::make_unique<core>())
{
}

audio_device_io_node::impl::~impl() = default;

void audio_device_io_node::impl::prepare(const audio_device_io_node &node, const audio_device &device)
{
    _core->weak_node = weak<audio_device_io_node>(node);
    set_device(device ?: audio_device::default_output_device());
}

UInt32 audio_device_io_node::impl::input_bus_count() const
{
    return 1;
}

UInt32 audio_device_io_node::impl::output_bus_count() const
{
    return 1;
}

void audio_device_io_node::impl::update_connections()
{
    auto &device_io = _core->device_io;
    if (!device_io) {
        return;
    }

    if (!_validate_connections()) {
        device_io.set_render_callback(nullptr);
        return;
    }

    auto weak_node = _core->weak_node;
    weak<audio_device_io> weak_device_io(device_io);

    auto render_function = [weak_node, weak_device_io](audio_pcm_buffer &output_buffer, const audio_time &when) {
        if (auto node = weak_node.lock()) {
            if (auto kernel = node._impl_ptr()->kernel_cast()) {
                if (output_buffer) {
                    const auto connections = kernel->input_connections();
                    if (connections.count(0) > 0) {
                        const auto &connection = connections.at(0);
                        if (auto source_node = connection.source_node()) {
                            if (connection.format() == source_node.output_format(connection.source_bus())) {
                                source_node.render(output_buffer, connection.source_bus(), when);
                            }
                        }
                    }
                }

                if (const auto device_io = weak_device_io.lock()) {
                    const auto connections = kernel->output_connections();
                    if (connections.count(0) > 0) {
                        const auto &connection = connections.at(0);
                        if (auto destination_node = connection.destination_node()) {
                            if (auto input_tap_node = destination_node.cast<audio_input_tap_node>()) {
                                auto input_buffer = device_io.input_buffer_on_render();
                                const audio_time &input_time = device_io.input_time_on_render();
                                if (input_buffer && input_time) {
                                    if (connection.format() ==
                                        destination_node.input_format(connection.destination_bus())) {
                                        input_tap_node.render(input_buffer, 0, input_time);
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

bool audio_device_io_node::impl::_validate_connections() const
{
    if (const auto &device_io = _core->device_io) {
        if (input_connections().size() > 0) {
            const auto connections = yas::lock_values(input_connections());
            if (connections.count(0) > 0) {
                const auto &connection = connections.at(0);
                const auto &connection_format = connection.format();
                const auto &device_format = device_io.device().output_format();
                if (connection_format != device_format) {
                    std::cout << __PRETTY_FUNCTION__ << " : output device io format is not match." << std::endl;
                    return false;
                }
            }
        }

        if (output_connections().size() > 0) {
            const auto connections = yas::lock_values(output_connections());
            if (connections.count(0) > 0) {
                const auto &connection = connections.at(0);
                const auto &connection_format = connection.format();
                const auto &device_format = device_io.device().input_format();
                if (connection_format != device_format) {
                    std::cout << __PRETTY_FUNCTION__ << " : input device io format is not match." << std::endl;
                    return false;
                }
            }
        }
    }

    return true;
}

void audio_device_io_node::impl::add_device_io_to_graph(audio_graph &graph)
{
    if (!graph) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_core->device_io) {
        return;
    }

    _core->weak_graph = graph;
    _core->device_io = audio_device_io(_core->device());
    graph.add_audio_device_io(_core->device_io);
}

void audio_device_io_node::impl::remove_device_io_from_graph()
{
    if (auto graph = _core->weak_graph.lock()) {
        if (_core->device_io) {
            graph.remove_audio_device_io(_core->device_io);
        }
    }

    _core->weak_graph.reset();
    _core->device_io = nullptr;
}

void audio_device_io_node::impl::set_device(const audio_device &device)
{
    _core->set_device(device);
}

audio_device audio_device_io_node::impl::device() const
{
    return _core->device();
}

void audio_device_io_node::impl::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    super_class::render(buffer, bus_idx, when);

    if (const auto &device_io = _core->device_io) {
        auto &input_buffer = device_io.input_buffer_on_render();
        if (input_buffer && input_buffer.format() == buffer.format()) {
            buffer.copy_from(input_buffer);
        }
    }
}

#endif
