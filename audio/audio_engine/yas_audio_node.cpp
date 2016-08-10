//
//  yas_audio_node.cpp
//

#include <iostream>
#include "yas_audio_connection.h"
#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_time.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - audio::node::impl

struct audio::node::impl : base::impl, manageable_node::impl, connectable_node::impl {
   private:
   public:
    weak<audio::engine> _weak_engine;
    subject_t _subject;
    uint32_t _input_bus_count = 0;
    uint32_t _output_bus_count = 0;
    bool _is_input_renderable = false;
    std::experimental::optional<uint32_t> _override_output_bus_idx = nullopt;
    audio::connection_wmap _input_connections;
    audio::connection_wmap _output_connections;
    edit_graph_f _add_to_graph_handler;
    edit_graph_f _remove_from_graph_handler;
    prepare_kernel_f _prepare_kernel_handler;
    audio::node::render_f _render_handler;

    explicit impl(node_args &&args)
        : _input_bus_count(args.input_bus_count),
          _output_bus_count(args.output_bus_count),
          _is_input_renderable(args.input_renderable),
          _override_output_bus_idx(args.override_output_bus_idx) {
    }

    void reset() {
        if (_subject.has_observer()) {
            _subject.notify(audio::node::method::will_reset, cast<audio::node>());
        }

        _input_connections.clear();
        _output_connections.clear();
        _core.set_render_time(nullptr);

        update_kernel();
    }

    audio::format input_format(uint32_t const bus_idx) {
        if (auto connection = input_connection(bus_idx)) {
            return connection.format();
        }
        return nullptr;
    }

    audio::format output_format(uint32_t const bus_idx) {
        if (auto connection = output_connection(bus_idx)) {
            return connection.format();
        }
        return nullptr;
    }

    audio::bus_result_t next_available_input_bus() const {
        auto key = min_empty_key(_input_connections);
        if (key && *key < input_bus_count()) {
            return key;
        }
        return nullopt;
    }

    audio::bus_result_t next_available_output_bus() const {
        auto key = min_empty_key(_output_connections);
        if (key && *key < output_bus_count()) {
            auto &override_bus_idx = _override_output_bus_idx;
            if (override_bus_idx && *key == 0) {
                return *override_bus_idx;
            }
            return key;
        }
        return nullopt;
    }

    bool is_available_input_bus(uint32_t const bus_idx) const {
        if (bus_idx >= input_bus_count()) {
            return false;
        }
        return _input_connections.count(bus_idx) == 0;
    }

    bool is_available_output_bus(uint32_t const bus_idx) const {
        auto &override_bus_idx = _override_output_bus_idx;
        auto target_bus_idx = (override_bus_idx && *override_bus_idx == bus_idx) ? 0 : bus_idx;
        if (target_bus_idx >= output_bus_count()) {
            return false;
        }
        return _output_connections.count(target_bus_idx) == 0;
    }

    void override_output_bus_idx(std::experimental::optional<uint32_t> bus_idx) {
        _override_output_bus_idx = bus_idx;
    }

    void set_input_bus_count(uint32_t const count) {
        _input_bus_count = count;
    }

    void set_output_bus_count(uint32_t const count) {
        _output_bus_count = count;
    }

    uint32_t input_bus_count() const {
        return _input_bus_count;
    }

    uint32_t output_bus_count() const {
        return _output_bus_count;
    }

    void set_is_input_renderable(bool const renderable) {
        _is_input_renderable = renderable;
    }

    bool is_input_renderable() {
        return _is_input_renderable;
    }

    audio::connection input_connection(uint32_t const bus_idx) override {
        if (_input_connections.count(bus_idx) > 0) {
            return _input_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::connection output_connection(uint32_t const bus_idx) override {
        if (_output_connections.count(bus_idx) > 0) {
            return _output_connections.at(bus_idx).lock();
        }
        return nullptr;
    }

    audio::connection_wmap &input_connections() override {
        return _input_connections;
    }

    audio::connection_wmap &output_connections() override {
        return _output_connections;
    }

    void update_connections() override {
        _subject.notify(audio::node::method::update_connections, cast<audio::node>());
    }

    void add_connection(connection const &connection) override {
        if (connection.destination_node().impl_ptr<impl>().get() == this) {
            auto bus_idx = connection.destination_bus();
            _input_connections.insert(std::make_pair(bus_idx, weak<audio::connection>(connection)));
        } else if (connection.source_node().impl_ptr<impl>().get() == this) {
            auto bus_idx = connection.source_bus();
            _output_connections.insert(std::make_pair(bus_idx, weak<audio::connection>(connection)));
        } else {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
        }

        update_kernel();
    }

    void remove_connection(connection const &connection) override {
        if (auto destination_node = connection.destination_node()) {
            if (connection.destination_node().impl_ptr<impl>().get() == this) {
                _input_connections.erase(connection.destination_bus());
            }
        }

        if (auto source_node = connection.source_node()) {
            if (connection.source_node().impl_ptr<impl>().get() == this) {
                _output_connections.erase(connection.source_bus());
            }
        }

        update_kernel();
    }

    void set_prepare_kernel_handler(prepare_kernel_f &&handler) {
        _prepare_kernel_handler = std::move(handler);
    }

    void prepare_kernel(audio::kernel &kernel) {
        if (!kernel) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        auto &manageable_kernel = kernel.manageable();
        manageable_kernel.set_input_connections(_input_connections);
        manageable_kernel.set_output_connections(_output_connections);

        if (_prepare_kernel_handler) {
            _prepare_kernel_handler(kernel);
        }
    }

    void update_kernel() override {
        auto kernel = audio::kernel{};
        prepare_kernel(kernel);
        _core.set_kernel(kernel);
    }

    audio::kernel kernel() {
        return _core.kernel();
    }

    audio::engine engine() const override {
        return _weak_engine.lock();
    }

    void set_engine(audio::engine const &engine) override {
        _weak_engine = engine;
    }

    void set_add_to_graph_handler(edit_graph_f &&handler) override {
        _add_to_graph_handler = std::move(handler);
    }

    void set_remove_from_graph_handler(edit_graph_f &&handler) override {
        _remove_from_graph_handler = std::move(handler);
    }

    edit_graph_f const &add_to_graph_handler() const override {
        return _add_to_graph_handler;
    }

    edit_graph_f const &remove_from_graph_handler() const override {
        return _remove_from_graph_handler;
    }

    audio::node::subject_t &subject() {
        return _subject;
    }

    void set_render_handler(audio::node::render_f &&handler) {
        _render_handler = std::move(handler);
    }

    void render(pcm_buffer &buffer, uint32_t const bus_idx, time const &when) {
        set_render_time_on_render(when);

        if (_render_handler) {
            _render_handler(buffer, bus_idx, when);
        }
    }

    audio::time render_time() {
        return _core.render_time();
    }

    void set_render_time_on_render(time const &time) {
        _core.set_render_time(time);
    }

   private:
    struct core {
        void set_kernel(audio::kernel kernel) {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            _kernel = std::move(kernel);
        }

        audio::kernel kernel() {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            return _kernel;
        }

        void set_render_time(time const &render_time) {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            _render_time = render_time;
        }

        audio::time render_time() const {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            return _render_time;
        }

       private:
        audio::kernel _kernel = nullptr;
        audio::time _render_time = nullptr;
        mutable std::recursive_mutex _mutex;
    };

    core _core;
};

#pragma mark - audio::node

audio::node::node(node_args args) : base(std::make_shared<impl>(std::move(args))) {
}

audio::node::node(std::nullptr_t) : base(nullptr) {
}

audio::node::~node() = default;

void audio::node::reset() {
    if (!impl_ptr()) {
        std::cout << "_impl is null" << std::endl;
    }
    impl_ptr<impl>()->reset();
}

audio::connection audio::node::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::connection audio::node::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::connection_wmap const &audio::node::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::connection_wmap const &audio::node::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

audio::format audio::node::input_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_format(bus_idx);
}

audio::format audio::node::output_format(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_format(bus_idx);
}

audio::bus_result_t audio::node::next_available_input_bus() const {
    return impl_ptr<impl>()->next_available_input_bus();
}

audio::bus_result_t audio::node::next_available_output_bus() const {
    return impl_ptr<impl>()->next_available_output_bus();
}

bool audio::node::is_available_input_bus(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->is_available_input_bus(bus_idx);
}

bool audio::node::is_available_output_bus(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->is_available_output_bus(bus_idx);
}

audio::engine audio::node::engine() const {
    return impl_ptr<impl>()->engine();
}

audio::time audio::node::last_render_time() const {
    return impl_ptr<impl>()->render_time();
}

uint32_t audio::node::input_bus_count() const {
    return impl_ptr<impl>()->input_bus_count();
}

uint32_t audio::node::output_bus_count() const {
    return impl_ptr<impl>()->output_bus_count();
}

bool audio::node::is_input_renderable() const {
    return impl_ptr<impl>()->is_input_renderable();
}

void audio::node::set_prepare_kernel_handler(prepare_kernel_f handler) {
    impl_ptr<impl>()->set_prepare_kernel_handler(std::move(handler));
}

void audio::node::set_render_handler(render_f handler) {
    impl_ptr<impl>()->set_render_handler(std::move(handler));
}

audio::kernel audio::node::kernel() const {
    return impl_ptr<impl>()->kernel();
}

#pragma mark render thread

void audio::node::render(pcm_buffer &buffer, uint32_t const bus_idx, const time &when) {
    impl_ptr<impl>()->render(buffer, bus_idx, when);
}

void audio::node::set_render_time_on_render(const time &time) {
    impl_ptr<impl>()->set_render_time_on_render(time);
}

audio::node::subject_t &audio::node::subject() {
    return impl_ptr<impl>()->subject();
}

audio::connectable_node &audio::node::connectable() {
    if (!_connectable) {
        _connectable = audio::connectable_node{impl_ptr<connectable_node::impl>()};
    }
    return _connectable;
}

audio::manageable_node const &audio::node::manageable() const {
    if (!_manageable) {
        _manageable = audio::manageable_node{impl_ptr<manageable_node::impl>()};
    }
    return _manageable;
}

audio::manageable_node &audio::node::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_node{impl_ptr<manageable_node::impl>()};
    }
    return _manageable;
}

#pragma mark -

std::string yas::to_string(audio::node::method const &method) {
    switch (method) {
        case audio::node::method::will_reset:
            return "will_reset";
        case audio::node::method::update_connections:
            return "update_connections";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::node::method const &value) {
    os << to_string(value);
    return os;
}
