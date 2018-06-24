//
//  yas_audio_node.cpp
//

#include "yas_audio_engine_node.h"
#include <iostream>
#include "yas_audio_engine_connection.h"
#include "yas_audio_engine_manager.h"
#include "yas_audio_time.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - audio::engine::node::impl

struct audio::engine::node::impl : base::impl, manageable_node::impl, connectable_node::impl {
    weak<audio::engine::manager> _weak_manager;
    uint32_t _input_bus_count = 0;
    uint32_t _output_bus_count = 0;
    bool _is_input_renderable = false;
    std::experimental::optional<uint32_t> _override_output_bus_idx = nullopt;
    audio::engine::connection_wmap _input_connections;
    audio::engine::connection_wmap _output_connections;
    graph_editing_f _add_to_graph_handler;
    graph_editing_f _remove_from_graph_handler;
    prepare_kernel_f _prepare_kernel_handler;
    audio::engine::node::render_f _render_handler;
    flow::notifier<flow_pair_t> _notifier;

    explicit impl(node_args &&args)
        : _input_bus_count(args.input_bus_count),
          _output_bus_count(args.output_bus_count),
          _is_input_renderable(args.input_renderable),
          _override_output_bus_idx(args.override_output_bus_idx) {
    }

    void reset() {
        this->_notifier.notify(std::make_pair(method::will_reset, cast<audio::engine::node>()));

        this->_input_connections.clear();
        this->_output_connections.clear();
        this->_core.set_render_time(nullptr);

        this->update_kernel();
    }

    audio::format input_format(uint32_t const bus_idx) {
        if (auto connection = this->input_connection(bus_idx)) {
            return connection.format();
        }
        return nullptr;
    }

    audio::format output_format(uint32_t const bus_idx) {
        if (auto connection = this->output_connection(bus_idx)) {
            return connection.format();
        }
        return nullptr;
    }

    audio::bus_result_t next_available_input_bus() const {
        auto key = min_empty_key(_input_connections);
        if (key && *key < this->input_bus_count()) {
            return key;
        }
        return nullopt;
    }

    audio::bus_result_t next_available_output_bus() const {
        auto key = min_empty_key(this->_output_connections);
        if (key && *key < output_bus_count()) {
            auto &override_bus_idx = this->_override_output_bus_idx;
            if (override_bus_idx && *key == 0) {
                return *override_bus_idx;
            }
            return key;
        }
        return nullopt;
    }

    bool is_available_input_bus(uint32_t const bus_idx) const {
        if (bus_idx >= this->input_bus_count()) {
            return false;
        }
        return this->_input_connections.count(bus_idx) == 0;
    }

    bool is_available_output_bus(uint32_t const bus_idx) const {
        auto &override_bus_idx = this->_override_output_bus_idx;
        auto target_bus_idx = (override_bus_idx && *override_bus_idx == bus_idx) ? 0 : bus_idx;
        if (target_bus_idx >= this->output_bus_count()) {
            return false;
        }
        return this->_output_connections.count(target_bus_idx) == 0;
    }

    void override_output_bus_idx(std::experimental::optional<uint32_t> bus_idx) {
        this->_override_output_bus_idx = bus_idx;
    }

    void set_input_bus_count(uint32_t const count) {
        this->_input_bus_count = count;
    }

    void set_output_bus_count(uint32_t const count) {
        this->_output_bus_count = count;
    }

    uint32_t input_bus_count() const {
        return this->_input_bus_count;
    }

    uint32_t output_bus_count() const {
        return this->_output_bus_count;
    }

    void set_is_input_renderable(bool const renderable) {
        this->_is_input_renderable = renderable;
    }

    bool is_input_renderable() {
        return this->_is_input_renderable;
    }

    audio::engine::connection input_connection(uint32_t const bus_idx) override {
        if (this->_input_connections.count(bus_idx) > 0) {
            return this->_input_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::engine::connection output_connection(uint32_t const bus_idx) override {
        if (this->_output_connections.count(bus_idx) > 0) {
            return this->_output_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::engine::connection_wmap &input_connections() override {
        return this->_input_connections;
    }

    audio::engine::connection_wmap &output_connections() override {
        return this->_output_connections;
    }

    void update_connections() override {
        this->_notifier.notify(std::make_pair(method::update_connections, cast<audio::engine::node>()));
    }

    void add_connection(engine::connection const &connection) override {
        if (connection.destination_node().impl_ptr<impl>().get() == this) {
            auto bus_idx = connection.destination_bus();
            this->_input_connections.insert(std::make_pair(bus_idx, weak<audio::engine::connection>(connection)));
        } else if (connection.source_node().impl_ptr<impl>().get() == this) {
            auto bus_idx = connection.source_bus();
            this->_output_connections.insert(std::make_pair(bus_idx, weak<audio::engine::connection>(connection)));
        } else {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
        }

        update_kernel();
    }

    void remove_connection(engine::connection const &connection) override {
        if (auto destination_node = connection.destination_node()) {
            if (connection.destination_node().impl_ptr<impl>().get() == this) {
                this->_input_connections.erase(connection.destination_bus());
            }
        }

        if (auto source_node = connection.source_node()) {
            if (connection.source_node().impl_ptr<impl>().get() == this) {
                this->_output_connections.erase(connection.source_bus());
            }
        }

        update_kernel();
    }

    void set_prepare_kernel_handler(prepare_kernel_f &&handler) {
        this->_prepare_kernel_handler = std::move(handler);
    }

    void prepare_kernel(audio::engine::kernel &kernel) {
        if (!kernel) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        auto &manageable_kernel = kernel.manageable();
        manageable_kernel.set_input_connections(_input_connections);
        manageable_kernel.set_output_connections(_output_connections);

        if (this->_prepare_kernel_handler) {
            this->_prepare_kernel_handler(kernel);
        }
    }

    void update_kernel() override {
        auto kernel = audio::engine::kernel{};
        prepare_kernel(kernel);
        this->_core.set_kernel(kernel);
    }

    audio::engine::kernel kernel() {
        return this->_core.kernel();
    }

    audio::engine::manager manager() const override {
        return this->_weak_manager.lock();
    }

    void set_manager(audio::engine::manager const &manager) override {
        this->_weak_manager = manager;
    }

    void set_add_to_graph_handler(graph_editing_f &&handler) override {
        this->_add_to_graph_handler = std::move(handler);
    }

    void set_remove_from_graph_handler(graph_editing_f &&handler) override {
        this->_remove_from_graph_handler = std::move(handler);
    }

    graph_editing_f const &add_to_graph_handler() const override {
        return this->_add_to_graph_handler;
    }

    graph_editing_f const &remove_from_graph_handler() const override {
        return this->_remove_from_graph_handler;
    }

    void set_render_handler(audio::engine::node::render_f &&handler) {
        this->_render_handler = std::move(handler);
    }

    void render(render_args &&args) {
        this->set_render_time_on_render(args.when);

        if (this->_render_handler) {
            this->_render_handler(std::move(args));
        }
    }

    audio::time render_time() {
        return this->_core.render_time();
    }

    void set_render_time_on_render(time const &time) {
        this->_core.set_render_time(time);
    }

   private:
    struct core {
        void set_kernel(audio::engine::kernel kernel) {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            this->_kernel = std::move(kernel);
        }

        audio::engine::kernel kernel() {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            return this->_kernel;
        }

        void set_render_time(time const &render_time) {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            this->_render_time = render_time;
        }

        audio::time render_time() const {
            std::lock_guard<std::recursive_mutex> lock(this->_mutex);
            return this->_render_time;
        }

       private:
        audio::engine::kernel _kernel = nullptr;
        audio::time _render_time = nullptr;
        mutable std::recursive_mutex _mutex;
    };

    core _core;
};

#pragma mark - audio::engine::node

audio::engine::node::node(node_args args) : base(std::make_shared<impl>(std::move(args))) {
}

audio::engine::node::node(std::nullptr_t) : base(nullptr) {
}

audio::engine::node::~node() = default;

void audio::engine::node::reset() {
    if (!impl_ptr()) {
        std::cout << "_impl is null" << std::endl;
    }
    impl_ptr<impl>()->reset();
}

audio::engine::connection audio::engine::node::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::engine::connection audio::engine::node::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::engine::connection_wmap const &audio::engine::node::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::engine::connection_wmap const &audio::engine::node::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

audio::format audio::engine::node::input_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_format(bus_idx);
}

audio::format audio::engine::node::output_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_format(bus_idx);
}

audio::bus_result_t audio::engine::node::next_available_input_bus() const {
    return impl_ptr<impl>()->next_available_input_bus();
}

audio::bus_result_t audio::engine::node::next_available_output_bus() const {
    return impl_ptr<impl>()->next_available_output_bus();
}

bool audio::engine::node::is_available_input_bus(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->is_available_input_bus(bus_idx);
}

bool audio::engine::node::is_available_output_bus(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->is_available_output_bus(bus_idx);
}

audio::engine::manager audio::engine::node::manager() const {
    return impl_ptr<impl>()->manager();
}

audio::time audio::engine::node::last_render_time() const {
    return impl_ptr<impl>()->render_time();
}

uint32_t audio::engine::node::input_bus_count() const {
    return impl_ptr<impl>()->input_bus_count();
}

uint32_t audio::engine::node::output_bus_count() const {
    return impl_ptr<impl>()->output_bus_count();
}

bool audio::engine::node::is_input_renderable() const {
    return impl_ptr<impl>()->is_input_renderable();
}

void audio::engine::node::set_prepare_kernel_handler(prepare_kernel_f handler) {
    impl_ptr<impl>()->set_prepare_kernel_handler(std::move(handler));
}

void audio::engine::node::set_render_handler(render_f handler) {
    impl_ptr<impl>()->set_render_handler(std::move(handler));
}

audio::engine::kernel audio::engine::node::kernel() const {
    return impl_ptr<impl>()->kernel();
}

#pragma mark render thread

void audio::engine::node::render(render_args args) {
    impl_ptr<impl>()->render(std::move(args));
}

void audio::engine::node::set_render_time_on_render(const time &time) {
    impl_ptr<impl>()->set_render_time_on_render(time);
}

flow::node_t<audio::engine::node::flow_pair_t, false> audio::engine::node::begin_flow() const {
    return impl_ptr<impl>()->_notifier.begin_flow();
}

flow::node<audio::engine::node, audio::engine::node::flow_pair_t, audio::engine::node::flow_pair_t, false>
audio::engine::node::begin_flow(method const method) const {
    return impl_ptr<impl>()
        ->_notifier.begin_flow()
        .filter([method](auto const &pair) { return pair.first == method; })
        .map([](flow_pair_t const &pair) { return pair.second; });
}

audio::engine::connectable_node &audio::engine::node::connectable() {
    if (!this->_connectable) {
        this->_connectable = audio::engine::connectable_node{impl_ptr<connectable_node::impl>()};
    }
    return this->_connectable;
}

audio::engine::manageable_node const &audio::engine::node::manageable() const {
    if (!this->_manageable) {
        this->_manageable = audio::engine::manageable_node{impl_ptr<manageable_node::impl>()};
    }
    return this->_manageable;
}

audio::engine::manageable_node &audio::engine::node::manageable() {
    if (!this->_manageable) {
        this->_manageable = audio::engine::manageable_node{impl_ptr<manageable_node::impl>()};
    }
    return this->_manageable;
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
