//
//  yas_audio_node.cpp
//

#include "yas_audio_engine_node.h"
#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>
#include <iostream>
#include "yas_audio_engine_connection.h"
#include "yas_audio_engine_manager.h"
#include "yas_audio_time.h"

using namespace yas;

#pragma mark - core

struct audio::engine::node::core {
    void set_kernel(audio::engine::kernel_ptr const &kernel) {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        this->_kernel = kernel;
    }

    audio::engine::kernel_ptr kernel() {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        return this->_kernel;
    }

    void set_render_time(std::optional<time> const &render_time) {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        this->_render_time = render_time;
    }

    std::optional<audio::time> render_time() const {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        return this->_render_time;
    }

   private:
    audio::engine::kernel_ptr _kernel = nullptr;
    std::optional<audio::time> _render_time = std::nullopt;
    mutable std::recursive_mutex _mutex;
};

#pragma mark - audio::engine::node

audio::engine::node::node(node_args &&args)
    : _input_bus_count(args.input_bus_count),
      _output_bus_count(args.output_bus_count),
      _is_input_renderable(args.input_renderable),
      _override_output_bus_idx(args.override_output_bus_idx),
      _core(std::make_unique<core>()) {
}

audio::engine::node::~node() = default;

void audio::engine::node::reset() {
    this->_notifier->notify(std::make_pair(method::will_reset, this->_weak_node.lock()));

    this->_input_connections.clear();
    this->_output_connections.clear();
    this->_core->set_render_time(std::nullopt);

    this->update_kernel();
}

audio::engine::connection_ptr audio::engine::node::input_connection(uint32_t const bus_idx) const {
    if (this->_input_connections.count(bus_idx) > 0) {
        return this->_input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::engine::connection_ptr audio::engine::node::output_connection(uint32_t const bus_idx) const {
    if (this->_output_connections.count(bus_idx) > 0) {
        return this->_output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio::engine::connection_wmap const &audio::engine::node::input_connections() const {
    return this->_input_connections;
}

audio::engine::connection_wmap const &audio::engine::node::output_connections() const {
    return this->_output_connections;
}

std::optional<audio::format> audio::engine::node::input_format(uint32_t const bus_idx) const {
    if (auto connection = this->input_connection(bus_idx)) {
        return connection->format;
    }
    return std::nullopt;
}

std::optional<audio::format> audio::engine::node::output_format(uint32_t const bus_idx) const {
    if (auto connection = this->output_connection(bus_idx)) {
        return connection->format;
    }
    return std::nullopt;
}

audio::bus_result_t audio::engine::node::next_available_input_bus() const {
    auto key = min_empty_key(this->_input_connections);
    if (key && *key < this->input_bus_count()) {
        return key;
    }
    return std::nullopt;
}

audio::bus_result_t audio::engine::node::next_available_output_bus() const {
    auto key = min_empty_key(this->_output_connections);
    if (key && *key < this->output_bus_count()) {
        auto &override_bus_idx = this->_override_output_bus_idx;
        if (override_bus_idx && *key == 0) {
            return *override_bus_idx;
        }
        return key;
    }
    return std::nullopt;
}

bool audio::engine::node::is_available_input_bus(uint32_t const bus_idx) const {
    if (bus_idx >= this->input_bus_count()) {
        return false;
    }
    return this->_input_connections.count(bus_idx) == 0;
}

bool audio::engine::node::is_available_output_bus(uint32_t const bus_idx) const {
    auto &override_bus_idx = this->_override_output_bus_idx;
    auto target_bus_idx = (override_bus_idx && *override_bus_idx == bus_idx) ? 0 : bus_idx;
    if (target_bus_idx >= this->output_bus_count()) {
        return false;
    }
    return this->_output_connections.count(target_bus_idx) == 0;
}

audio::engine::manager const &audio::engine::node::manager() const {
    manager_ptr shared = this->_weak_manager.lock();
    return *shared;
}

std::optional<audio::time> audio::engine::node::last_render_time() const {
    return this->_core->render_time();
}

uint32_t audio::engine::node::input_bus_count() const {
    return this->_input_bus_count;
}

uint32_t audio::engine::node::output_bus_count() const {
    return this->_output_bus_count;
}

bool audio::engine::node::is_input_renderable() const {
    return this->_is_input_renderable;
}

void audio::engine::node::set_prepare_kernel_handler(prepare_kernel_f handler) {
    this->_prepare_kernel_handler = std::move(handler);
}

void audio::engine::node::set_render_handler(render_f handler) {
    this->_render_handler = std::move(handler);
}

audio::engine::kernel_ptr audio::engine::node::kernel() const {
    return this->_core->kernel();
}

#pragma mark render thread

void audio::engine::node::render(render_args args) {
    this->set_render_time_on_render(args.when);

    if (this->_render_handler) {
        this->_render_handler(std::move(args));
    }
}

void audio::engine::node::set_render_time_on_render(const time &time) {
    this->_core->set_render_time(time);
}

chaining::chain_unsync_t<audio::engine::node::chaining_pair_t> audio::engine::node::chain() const {
    return this->_notifier->chain();
}

chaining::chain_relayed_unsync_t<audio::engine::node_ptr, audio::engine::node::chaining_pair_t>
audio::engine::node::chain(method const method) const {
    return this->_notifier->chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](chaining_pair_t const &pair) { return pair.second; });
}

audio::engine::connectable_node_ptr audio::engine::node::connectable() {
    return std::dynamic_pointer_cast<connectable_node>(this->_weak_node.lock());
}

audio::engine::manageable_node_ptr audio::engine::node::manageable() {
    return std::dynamic_pointer_cast<manageable_node>(this->_weak_node.lock());
}

void audio::engine::node::add_connection(audio::engine::connection_ptr const &connection) {
    auto weak_connection = to_weak(connection);
    if (connection->destination_node().get() == this) {
        auto bus_idx = connection->destination_bus;
        this->_input_connections.insert(std::make_pair(bus_idx, weak_connection));
    } else if (connection->source_node().get() == this) {
        auto bus_idx = connection->source_bus;
        this->_output_connections.insert(std::make_pair(bus_idx, weak_connection));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    this->update_kernel();
}

void audio::engine::node::remove_input_connection(uint32_t const dst_bus) {
    this->_input_connections.erase(dst_bus);
    this->update_kernel();
}

void audio::engine::node::remove_output_connection(uint32_t const src_bus) {
    this->_output_connections.erase(src_bus);
    this->update_kernel();
}

void audio::engine::node::set_manager(audio::engine::manager_ptr const &manager) {
    this->_weak_manager = manager;
}

void audio::engine::node::update_kernel() {
    auto kernel = audio::engine::kernel::make_shared();
    this->_prepare_kernel(kernel);
    this->_core->set_kernel(kernel);
}

void audio::engine::node::update_connections() {
    this->_notifier->notify(std::make_pair(method::update_connections, this->_weak_node.lock()));
}

void audio::engine::node::set_add_to_graph_handler(graph_editing_f &&handler) {
    this->_add_to_graph_handler = std::move(handler);
}

void audio::engine::node::set_remove_from_graph_handler(graph_editing_f &&handler) {
    this->_remove_from_graph_handler = std::move(handler);
}

audio::graph_editing_f const &audio::engine::node::add_to_graph_handler() const {
    return this->_add_to_graph_handler;
}
audio::graph_editing_f const &audio::engine::node::remove_from_graph_handler() const {
    return this->_remove_from_graph_handler;
}

void audio::engine::node::_prepare(node_ptr const &shared) {
    this->_weak_node = shared;
}

void audio::engine::node::_prepare_kernel(kernel_ptr const &kernel) {
    auto manageable_kernel = kernel->manageable();
    manageable_kernel->set_input_connections(_input_connections);
    manageable_kernel->set_output_connections(_output_connections);

    if (this->_prepare_kernel_handler) {
        this->_prepare_kernel_handler(*kernel);
    }
}

audio::engine::node_ptr audio::engine::node::make_shared(node_args args) {
    auto shared = node_ptr(new node{std::move(args)});
    shared->_prepare(shared);
    return shared;
}

#pragma mark -

std::string yas::to_string(audio::engine::node::method const &method) {
    switch (method) {
        case audio::engine::node::method::will_reset:
            return "will_reset";
        case audio::engine::node::method::update_connections:
            return "update_connections";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::engine::node::method const &value) {
    os << to_string(value);
    return os;
}
