//
//  yas_audio_device_io_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"
#include "yas_audio_device_io.h"
#include "yas_audio_tap_node.h"
#include "yas_audio_graph.h"
#include "yas_stl_utils.h"
#include <set>

using namespace yas;

#pragma mark - impl

class audio_device_io_node::impl
{
   public:
    std::weak_ptr<audio_device_io_node> weak_node;
    audio_graph_wptr graph;
    audio_device_io_sptr device_io;
    audio_node_core_sptr node_core_on_render;

    impl() : weak_node(), _device(nullptr), graph(), device_io(nullptr), node_core_on_render(nullptr)
    {
    }

    ~impl() = default;

    void set_device(const audio_device_sptr &device)
    {
        _device = device;
        if (device_io) {
            device_io->set_device(device);
        }
    }

    audio_device_sptr device() const
    {
        return _device;
    }

   private:
    audio_device_sptr _device;
};

#pragma mark - main

audio_device_io_node_sptr audio_device_io_node::create(const audio_device_sptr &device)
{
    auto node = audio_device_io_node_sptr(new audio_device_io_node(device));
    node->_impl->weak_node = node;
    return node;
}

audio_device_io_node::audio_device_io_node(const audio_device_sptr &device)
    : audio_node(), _impl(std::make_unique<impl>())
{
    if (device) {
        set_device(device);
    } else {
        set_device(audio_device::default_output_device());
    }
}

audio_device_io_node::~audio_device_io_node() = default;

uint32_t audio_device_io_node::input_bus_count() const
{
    return 1;
}

uint32_t audio_device_io_node::output_bus_count() const
{
    return 1;
}

void audio_device_io_node::set_device(const audio_device_sptr &device)
{
    _impl->set_device(device);
}

audio_device_sptr audio_device_io_node::device() const
{
    return _impl->device();
}

#pragma mark - override

void audio_device_io_node::update_connections()
{
    auto &device_io = _impl->device_io;
    if (!device_io) {
        return;
    }

    if (!_validate_connections()) {
        device_io->set_render_callback(nullptr);
        return;
    }

    auto weak_node = _impl->weak_node;
    std::weak_ptr<audio_device_io> weak_device_io = device_io;

    auto render_function = [weak_node, weak_device_io](const audio_pcm_buffer_sptr &output_buffer,
                                                       const audio_time_sptr &when) {
        if (auto node = weak_node.lock()) {
            if (auto core = node->node_core()) {
                node->_impl->node_core_on_render = core;

                if (output_buffer) {
                    const auto connections = core->input_connections();
                    if (connections.count(0) > 0) {
                        const auto &connection = connections.at(0);
                        if (const auto source_node = connection->source_node()) {
                            if (*connection->format() == *source_node->output_format(connection->source_bus())) {
                                source_node->render(output_buffer, connection->source_bus(), when);
                            }
                        }
                    }
                }

                if (const auto device_io = weak_device_io.lock()) {
                    const auto connections = core->output_connections();
                    if (connections.count(0) > 0) {
                        const auto &connection = connections.at(0);
                        if (const auto destination_node = connection->destination_node()) {
                            if (auto *input_tap_node = dynamic_cast<audio_input_tap_node *>(destination_node.get())) {
                                const auto input_buffer = device_io->input_buffer_on_render();
                                const auto input_time = device_io->input_time_on_render();
                                if (input_buffer && input_time) {
                                    if (*connection->format() ==
                                        *destination_node->input_format(connection->destination_bus())) {
                                        input_tap_node->render(input_buffer, 0, input_time);
                                    }
                                }
                            }
                        }
                    }
                }

                node->_impl->node_core_on_render = nullptr;
            }
        }
    };

    device_io->set_render_callback(render_function);
}

#pragma mark - private

void audio_device_io_node::_add_device_io_to_graph(const audio_graph_sptr &graph)
{
    if (!graph) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_impl->device_io) {
        return;
    }

    _impl->graph = graph;
    _impl->device_io = yas::audio_device_io::create(_impl->device());
    graph->add_audio_device_io(_impl->device_io);
}

void audio_device_io_node::_remove_device_io_from_graph()
{
    if (auto graph = _impl->graph.lock()) {
        if (_impl->device_io) {
            graph->remove_audio_device_io(_impl->device_io);
        }
    }

    _impl->graph.reset();
    _impl->device_io = nullptr;
}

bool audio_device_io_node::_validate_connections() const
{
    if (const auto &device_io = _impl->device_io) {
        if (input_connections().size() > 0) {
            const auto connections = yas::lock_values(input_connections());
            if (connections.count(0) > 0) {
                const auto &connection = connections.at(0);
                const auto &connection_format = connection->format();
                const auto &device_format = device_io->device()->output_format();
                if (*connection_format != *device_format) {
                    std::cout << __PRETTY_FUNCTION__ << " : output device io format is not match." << std::endl;
                    return false;
                }
            }
        }

        if (output_connections().size() > 0) {
            const auto connections = yas::lock_values(output_connections());
            if (connections.count(0) > 0) {
                const auto &connection = connections.at(0);
                const auto &connection_format = connection->format();
                const auto &device_format = device_io->device()->input_format();
                if (*connection_format != *device_format) {
                    std::cout << __PRETTY_FUNCTION__ << " : input device io format is not match." << std::endl;
                    return false;
                }
            }
        }
    }

    return true;
}

#pragma mark - render

void audio_device_io_node::render(const audio_pcm_buffer_sptr &buffer, const uint32_t bus_idx,
                                  const audio_time_sptr &when)
{
    super_class::render(buffer, bus_idx, when);

    if (const auto &device_io = _impl->device_io) {
        if (auto core = _impl->node_core_on_render) {
            auto &input_buffer = device_io->input_buffer_on_render();
            if (input_buffer && *input_buffer->format() == *buffer->format()) {
                buffer->copy_from(input_buffer);
            }
        }
    }
}

#endif
