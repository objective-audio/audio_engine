//
//  yas_audio_node_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_time.h"
#include "yas_stl_utils.h"

using namespace yas;

class audio::node::impl::core {
   public:
    weak<audio::engine> weak_engine;
    connection_wmap input_connections;
    connection_wmap output_connections;

    core()
        : weak_engine(), input_connections(), output_connections(), _kernel(nullptr), _render_time(nullptr), _mutex() {
    }

    void reset() {
        input_connections.clear();
        output_connections.clear();
        set_render_time(nullptr);
    }

    void set_kernel(const std::shared_ptr<kernel> &kernel) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = kernel;
    }

    std::shared_ptr<kernel> kernel() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void set_render_time(const time &render_time) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_time = render_time;
    }

    time render_time() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_time;
    }

   private:
    std::shared_ptr<node::kernel> _kernel;
    time _render_time;
    mutable std::recursive_mutex _mutex;
};

audio::node::impl::impl() : _core(std::make_unique<core>()) {
}

audio::node::impl::~impl() = default;

void audio::node::impl::reset() {
    _core->reset();
    update_kernel();
}

audio::format audio::node::impl::input_format(const UInt32 bus_idx) {
    if (auto connection = input_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio::format audio::node::impl::output_format(const UInt32 bus_idx) {
    if (auto connection = output_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio::bus_result_t audio::node::impl::next_available_input_bus() const {
    auto key = min_empty_key(_core->input_connections);
    if (key && *key < input_bus_count()) {
        return key;
    }
    return nullopt;
}

audio::bus_result_t audio::node::impl::next_available_output_bus() const {
    auto key = min_empty_key(_core->output_connections);
    if (key && *key < output_bus_count()) {
        return key;
    }
    return nullopt;
}

bool audio::node::impl::is_available_input_bus(const UInt32 bus_idx) const {
    if (bus_idx >= input_bus_count()) {
        return false;
    }
    return _core->input_connections.count(bus_idx) == 0;
}

bool audio::node::impl::is_available_output_bus(const UInt32 bus_idx) const {
    if (bus_idx >= output_bus_count()) {
        return false;
    }
    return _core->output_connections.count(bus_idx) == 0;
}

UInt32 audio::node::impl::input_bus_count() const {
    return 0;
}

UInt32 audio::node::impl::output_bus_count() const {
    return 0;
}

audio::connection audio::node::impl::input_connection(const UInt32 bus_idx) const {
    if (_core->input_connections.count(bus_idx) > 0) {
        return _core->input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection audio::node::impl::output_connection(const UInt32 bus_idx) const {
    if (_core->output_connections.count(bus_idx) > 0) {
        return _core->output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection_wmap &audio::node::impl::input_connections() const {
    return _core->input_connections;
}

audio::connection_wmap &audio::node::impl::output_connections() const {
    return _core->output_connections;
}

void audio::node::impl::update_connections() {
}

std::shared_ptr<audio::node::kernel> audio::node::impl::make_kernel() {
    return std::shared_ptr<kernel>(new kernel());
}

void audio::node::impl::prepare_kernel(const std::shared_ptr<kernel> &kernel) {
    if (!kernel) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto knl = std::static_pointer_cast<kernel_from_node>(kernel);
    knl->_set_input_connections(_core->input_connections);
    knl->_set_output_connections(_core->output_connections);
}

void audio::node::impl::update_kernel() {
    auto kernel = make_kernel();
    prepare_kernel(kernel);
    _core->set_kernel(kernel);
}

std::shared_ptr<audio::node::kernel> audio::node::impl::_kernel() const {
    return _core->kernel();
}

audio::engine audio::node::impl::engine() const {
    return _core->weak_engine.lock();
}

void audio::node::impl::set_engine(const audio::engine &engine) {
    _core->weak_engine = engine;
}

void audio::node::impl::add_connection(const connection &connection) {
    if (connection.destination_node().impl_ptr<impl>()->_core == _core) {
        auto bus_idx = connection.destination_bus();
        _core->input_connections.insert(std::make_pair(bus_idx, weak<audio::connection>(connection)));
    } else if (connection.source_node().impl_ptr<impl>()->_core == _core) {
        auto bus_idx = connection.source_bus();
        _core->output_connections.insert(std::make_pair(bus_idx, weak<audio::connection>(connection)));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    update_kernel();
}

void audio::node::impl::remove_connection(const connection &connection) {
    if (auto destination_node = connection.destination_node()) {
        if (connection.destination_node().impl_ptr<impl>()->_core == _core) {
            _core->input_connections.erase(connection.destination_bus());
        }
    }

    if (auto source_node = connection.source_node()) {
        if (connection.source_node().impl_ptr<impl>()->_core == _core) {
            _core->output_connections.erase(connection.source_bus());
        }
    }

    update_kernel();
}

void audio::node::impl::render(pcm_buffer &buffer, const UInt32 bus_idx, const time &when) {
    set_render_time_on_render(when);
}

audio::time audio::node::impl::render_time() const {
    return _core->render_time();
}

void audio::node::impl::set_render_time_on_render(const time &time) {
    _core->set_render_time(time);
}