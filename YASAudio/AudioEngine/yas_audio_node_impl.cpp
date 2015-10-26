//
//  yas_audio_node_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_node.h"
#include "yas_audio_time.h"
#include "yas_stl_utils.h"

using namespace yas;

class audio_node::impl::core
{
   public:
    weak<audio_engine> weak_engine;
    weak<audio_node> weak_node;
    audio_connection_wmap input_connections;
    audio_connection_wmap output_connections;

    core() : weak_engine(), input_connections(), output_connections(), _kernel(nullptr), _render_time(), _mutex()
    {
    }

    void reset()
    {
        input_connections.clear();
        output_connections.clear();
        set_render_time(nullptr);
    }

    void set_kernel(const std::shared_ptr<kernel> &kernel)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = kernel;
    }

    std::shared_ptr<kernel> kernel() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void set_render_time(const audio_time &render_time)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_time = render_time;
    }

    audio_time render_time() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_time;
    }

   private:
    std::shared_ptr<audio_node::kernel> _kernel;
    audio_time _render_time;
    mutable std::recursive_mutex _mutex;
};

audio_node::impl::impl() : _core(std::make_unique<core>())
{
}

audio_node::impl::~impl() = default;

void audio_node::impl::reset()
{
    _core->reset();
    update_kernel();
}

audio_format audio_node::impl::input_format(const UInt32 bus_idx)
{
    if (auto connection = input_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio_format audio_node::impl::output_format(const UInt32 bus_idx)
{
    if (auto connection = output_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

bus_result_t audio_node::impl::next_available_input_bus() const
{
    auto key = min_empty_key(_core->input_connections);
    if (key && *key < input_bus_count()) {
        return key;
    }
    return nullopt;
}

bus_result_t audio_node::impl::next_available_output_bus() const
{
    auto key = min_empty_key(_core->output_connections);
    if (key && *key < output_bus_count()) {
        return key;
    }
    return nullopt;
}

bool audio_node::impl::is_available_input_bus(const UInt32 bus_idx) const
{
    if (bus_idx >= input_bus_count()) {
        return false;
    }
    return _core->input_connections.count(bus_idx) == 0;
}

bool audio_node::impl::is_available_output_bus(const UInt32 bus_idx) const
{
    if (bus_idx >= output_bus_count()) {
        return false;
    }
    return _core->output_connections.count(bus_idx) == 0;
}

UInt32 audio_node::impl::input_bus_count() const
{
    return 0;
}

UInt32 audio_node::impl::output_bus_count() const
{
    return 0;
}

audio_connection audio_node::impl::input_connection(const UInt32 bus_idx) const
{
    if (_core->input_connections.count(bus_idx) > 0) {
        return _core->input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection audio_node::impl::output_connection(const UInt32 bus_idx) const
{
    if (_core->output_connections.count(bus_idx) > 0) {
        return _core->output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection_wmap &audio_node::impl::input_connections() const
{
    return _core->input_connections;
}

audio_connection_wmap &audio_node::impl::output_connections() const
{
    return _core->output_connections;
}

void audio_node::impl::update_connections()
{
}

std::shared_ptr<audio_node::kernel> audio_node::impl::make_kernel()
{
    return std::shared_ptr<kernel>(new kernel());
}

void audio_node::impl::prepare_kernel(const std::shared_ptr<kernel> &kernel)
{
    if (!kernel) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    kernel::private_access::set_input_connections(kernel, _core->input_connections);
    kernel::private_access::set_output_connections(kernel, _core->output_connections);
}

void audio_node::impl::update_kernel()
{
    auto kernel = make_kernel();
    prepare_kernel(kernel);
    _core->set_kernel(kernel);
}

std::shared_ptr<audio_node::kernel> audio_node::impl::_kernel() const
{
    return _core->kernel();
}

void audio_node::impl::set_node(const audio_node &node)
{
    _core->weak_node = node;
}

audio_node audio_node::impl::node() const
{
    return _core->weak_node.lock();
}

audio_engine audio_node::impl::engine() const
{
    return _core->weak_engine.lock();
}

void audio_node::impl::set_engine(const audio_engine &engine)
{
    _core->weak_engine = engine;
}

void audio_node::impl::add_connection(const audio_connection &connection)
{
    if (connection.destination_node()._impl->_core == _core) {
        auto bus_idx = connection.destination_bus();
        _core->input_connections.insert(std::make_pair(bus_idx, weak<audio_connection>(connection)));
    } else if (connection.source_node()._impl->_core == _core) {
        auto bus_idx = connection.source_bus();
        _core->output_connections.insert(std::make_pair(bus_idx, weak<audio_connection>(connection)));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    update_kernel();
}

void audio_node::impl::remove_connection(const audio_connection &connection)
{
    if (auto destination_node = connection.destination_node()) {
        if (connection.destination_node()._impl->_core == _core) {
            _core->input_connections.erase(connection.destination_bus());
        }
    }

    if (auto source_node = connection.source_node()) {
        if (connection.source_node()._impl->_core == _core) {
            _core->output_connections.erase(connection.source_bus());
        }
    }

    update_kernel();
}

void audio_node::impl::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    set_render_time_on_render(when);
}

audio_time audio_node::impl::render_time() const
{
    return _core->render_time();
}

void audio_node::impl::set_render_time_on_render(const audio_time &time)
{
    _core->set_render_time(time);
}