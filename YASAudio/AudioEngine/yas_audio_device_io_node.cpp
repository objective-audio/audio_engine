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
#include "yas_audio_time.h"
#include "yas_stl_utils.h"
#include <set>

using namespace yas;

#pragma mark - impl

class audio_device_io_node::impl : public audio_node::impl
{
   public:
    impl() : audio_node::impl(), _core(std::make_unique<core>())
    {
    }

    ~impl() = default;

    virtual UInt32 input_bus_count() const override
    {
        return 1;
    }

    virtual UInt32 output_bus_count() const override
    {
        return 1;
    }

    class core;
    std::unique_ptr<core> _core;
};

class audio_device_io_node::impl::core
{
   public:
    std::weak_ptr<audio_device_io_node> weak_node;
    audio_graph::weak weak_graph;
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

#pragma mark - main

audio_device_io_node_sptr audio_device_io_node::create()
{
    auto node = audio_device_io_node_sptr(new audio_device_io_node(nullptr));
    node->_impl_ptr()->_core->weak_node = node;
    return node;
}

audio_device_io_node_sptr audio_device_io_node::create(const audio_device &device)
{
    auto node = audio_device_io_node_sptr(new audio_device_io_node(device));
    node->_impl_ptr()->_core->weak_node = node;
    return node;
}

audio_device_io_node::audio_device_io_node(const audio_device &device)
    : audio_node(std::make_unique<audio_device_io_node::impl>())
{
    if (device) {
        set_device(device);
    } else {
        set_device(audio_device::default_output_device());
    }
}

audio_device_io_node::~audio_device_io_node() = default;

void audio_device_io_node::set_device(const audio_device &device)
{
    _impl_ptr()->_core->set_device(device);
}

audio_device audio_device_io_node::device() const
{
    return _impl_ptr()->_core->device();
}

#pragma mark - override

void audio_device_io_node::update_connections()
{
    auto &device_io = _impl_ptr()->_core->device_io;
    if (!device_io) {
        return;
    }

    if (!_validate_connections()) {
        device_io.set_render_callback(nullptr);
        return;
    }

    auto weak_node = _impl_ptr()->_core->weak_node;
    audio_device_io::weak weak_device_io(device_io);

    auto render_function = [weak_node, weak_device_io](audio_pcm_buffer &output_buffer, const audio_time &when) {
        if (auto node = weak_node.lock()) {
            if (auto kernel = node->_kernel()) {
                if (output_buffer) {
                    const auto connections = kernel->input_connections();
                    if (connections.count(0) > 0) {
                        const auto &connection = connections.at(0);
                        if (const auto source_node = connection.source_node()) {
                            if (connection.format() == source_node->output_format(connection.source_bus())) {
                                source_node->render(output_buffer, connection.source_bus(), when);
                            }
                        }
                    }
                }

                if (const auto device_io = weak_device_io.lock()) {
                    const auto connections = kernel->output_connections();
                    if (connections.count(0) > 0) {
                        const auto &connection = connections.at(0);
                        if (const auto destination_node = connection.destination_node()) {
                            if (auto *input_tap_node = dynamic_cast<audio_input_tap_node *>(destination_node.get())) {
                                auto input_buffer = device_io.input_buffer_on_render();
                                const audio_time &input_time = device_io.input_time_on_render();
                                if (input_buffer && input_time) {
                                    if (connection.format() ==
                                        destination_node->input_format(connection.destination_bus())) {
                                        input_tap_node->render(input_buffer, 0, input_time);
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

#pragma mark - private

void audio_device_io_node::_add_device_io_to_graph(audio_graph &graph)
{
    if (!graph) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_impl_ptr()->_core->device_io) {
        return;
    }

    _impl_ptr()->_core->weak_graph = graph;
    _impl_ptr()->_core->device_io = audio_device_io(_impl_ptr()->_core->device());
    graph.add_audio_device_io(_impl_ptr()->_core->device_io);
}

void audio_device_io_node::_remove_device_io_from_graph()
{
    if (auto graph = _impl_ptr()->_core->weak_graph.lock()) {
        if (_impl_ptr()->_core->device_io) {
            graph.remove_audio_device_io(_impl_ptr()->_core->device_io);
        }
    }

    _impl_ptr()->_core->weak_graph.reset();
    _impl_ptr()->_core->device_io = nullptr;
}

bool audio_device_io_node::_validate_connections() const
{
    if (const auto &device_io = _impl_ptr()->_core->device_io) {
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

audio_device_io_node::impl *audio_device_io_node::_impl_ptr() const
{
    return dynamic_cast<audio_device_io_node::impl *>(_impl.get());
}

#pragma mark - render

void audio_device_io_node::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    super_class::render(buffer, bus_idx, when);

    if (const auto &device_io = _impl_ptr()->_core->device_io) {
        auto &input_buffer = device_io.input_buffer_on_render();
        if (input_buffer && input_buffer.format() == buffer.format()) {
            buffer.copy_from(input_buffer);
        }
    }
}

#endif
