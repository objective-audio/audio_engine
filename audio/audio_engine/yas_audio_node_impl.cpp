//
//  yas_audio_node_impl.cpp
//

#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_time.h"
#include "yas_stl_utils.h"

using namespace yas;

struct audio::node::impl::core {
    weak<audio::engine> _weak_engine;
    connection_wmap _input_connections;
    connection_wmap _output_connections;

    core() {
    }

    void reset() {
        _input_connections.clear();
        _output_connections.clear();
        set_render_time(nullptr);
    }

    void set_kernel(node::kernel kernel) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = std::move(kernel);
    }

    node::kernel kernel() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void set_render_time(time const &render_time) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_time = render_time;
    }

    time render_time() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_time;
    }

   private:
    node::kernel _kernel = nullptr;
    time _render_time = nullptr;
    mutable std::recursive_mutex _mutex;
};

audio::node::impl::impl() : _core(std::make_unique<core>()) {
}

audio::node::impl::~impl() = default;

void audio::node::impl::reset() {
    _core->reset();
    update_kernel();
}

audio::format audio::node::impl::input_format(uint32_t const bus_idx) {
    if (auto connection = input_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio::format audio::node::impl::output_format(uint32_t const bus_idx) {
    if (auto connection = output_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio::bus_result_t audio::node::impl::next_available_input_bus() const {
    auto key = min_empty_key(_core->_input_connections);
    if (key && *key < input_bus_count()) {
        return key;
    }
    return nullopt;
}

audio::bus_result_t audio::node::impl::next_available_output_bus() const {
    auto key = min_empty_key(_core->_output_connections);
    if (key && *key < output_bus_count()) {
        return key;
    }
    return nullopt;
}

bool audio::node::impl::is_available_input_bus(uint32_t const bus_idx) const {
    if (bus_idx >= input_bus_count()) {
        return false;
    }
    return _core->_input_connections.count(bus_idx) == 0;
}

bool audio::node::impl::is_available_output_bus(uint32_t const bus_idx) const {
    if (bus_idx >= output_bus_count()) {
        return false;
    }
    return _core->_output_connections.count(bus_idx) == 0;
}

uint32_t audio::node::impl::input_bus_count() const {
    return 0;
}

uint32_t audio::node::impl::output_bus_count() const {
    return 0;
}

audio::connection audio::node::impl::input_connection(uint32_t const bus_idx) const {
    if (_core->_input_connections.count(bus_idx) > 0) {
        return _core->_input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection audio::node::impl::output_connection(uint32_t const bus_idx) const {
    if (_core->_output_connections.count(bus_idx) > 0) {
        return _core->_output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::connection_wmap &audio::node::impl::input_connections() const {
    return _core->_input_connections;
}

audio::connection_wmap &audio::node::impl::output_connections() const {
    return _core->_output_connections;
}

void audio::node::impl::update_connections() {
}

audio::node::kernel audio::node::impl::make_kernel() {
    return audio::node::kernel{};
}

void audio::node::impl::prepare_kernel(audio::node::kernel &kernel) {
    if (!kernel) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto &manageable_kernel = kernel.manageable();
    manageable_kernel.set_input_connections(_core->_input_connections);
    manageable_kernel.set_output_connections(_core->_output_connections);
}

void audio::node::impl::update_kernel() {
    auto kernel = make_kernel();
    prepare_kernel(kernel);
    _core->set_kernel(kernel);
}

audio::node::kernel audio::node::impl::_kernel() const {
    return _core->kernel();
}

audio::engine audio::node::impl::engine() const {
    return _core->_weak_engine.lock();
}

void audio::node::impl::set_engine(audio::engine const &engine) {
    _core->_weak_engine = engine;
}

void audio::node::impl::add_connection(connection const &connection) {
    if (connection.destination_node().impl_ptr<impl>()->_core == _core) {
        auto bus_idx = connection.destination_bus();
        _core->_input_connections.insert(std::make_pair(bus_idx, weak<audio::connection>(connection)));
    } else if (connection.source_node().impl_ptr<impl>()->_core == _core) {
        auto bus_idx = connection.source_bus();
        _core->_output_connections.insert(std::make_pair(bus_idx, weak<audio::connection>(connection)));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    update_kernel();
}

void audio::node::impl::remove_connection(connection const &connection) {
    if (auto destination_node = connection.destination_node()) {
        if (connection.destination_node().impl_ptr<impl>()->_core == _core) {
            _core->_input_connections.erase(connection.destination_bus());
        }
    }

    if (auto source_node = connection.source_node()) {
        if (connection.source_node().impl_ptr<impl>()->_core == _core) {
            _core->_output_connections.erase(connection.source_bus());
        }
    }

    update_kernel();
}

void audio::node::impl::render(pcm_buffer &buffer, uint32_t const bus_idx, time const &when) {
    set_render_time_on_render(when);
}

audio::time audio::node::impl::render_time() const {
    return _core->render_time();
}

void audio::node::impl::set_render_time_on_render(time const &time) {
    _core->set_render_time(time);
}