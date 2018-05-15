//
//  yas_audio_connection.cpp
//

#include "yas_audio_engine_connection.h"
#include <mutex>
#include "yas_audio_engine_node.h"

using namespace yas;

struct audio::engine::connection::impl : base::impl, node_removable::impl {
    uint32_t _source_bus;
    uint32_t _destination_bus;
    audio::format _format;
    mutable std::recursive_mutex _mutex;

    impl(node const &src_node, uint32_t const src_bus, node const &dst_node, uint32_t const dst_bus,
         audio::format const &format)
        : _source_bus(src_bus),
          _destination_bus(dst_bus),
          _format(format),
          _source_node(src_node),
          _destination_node(dst_node) {
    }

    void remove_connection_from_nodes(connection const &connection) {
        if (auto node = _destination_node.lock()) {
            node.connectable().remove_connection(connection);
        }
        if (auto node = _source_node.lock()) {
            node.connectable().remove_connection(connection);
        }
    }

    node source_node() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _source_node.lock();
    }

    node destination_node() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _destination_node.lock();
    }

    void remove_nodes() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _source_node.reset();
        _destination_node.reset();
    }

    void remove_source_node() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _source_node.reset();
    }

    void remove_destination_node() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _destination_node.reset();
    }

   private:
    weak<node> _source_node;
    weak<node> _destination_node;
};

audio::engine::connection::connection(node &src_node, uint32_t const src_bus, node &dst_node, uint32_t const dst_bus,
                                      audio::format const &format)
    : base(std::make_shared<impl>(src_node, src_bus, dst_node, dst_bus, format)) {
    if (!src_node || !dst_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }

    src_node.connectable().add_connection(*this);
    dst_node.connectable().add_connection(*this);
}

audio::engine::connection::connection(std::nullptr_t) : base(nullptr) {
}

audio::engine::connection::~connection() {
    if (impl_ptr() && impl_ptr().unique()) {
        if (auto imp = impl_ptr<impl>()) {
            imp->remove_connection_from_nodes(*this);
        }
        impl_ptr().reset();
    }
}

uint32_t audio::engine::connection::source_bus() const {
    return impl_ptr<impl>()->_source_bus;
}

uint32_t audio::engine::connection::destination_bus() const {
    return impl_ptr<impl>()->_destination_bus;
}

audio::engine::node audio::engine::connection::source_node() const {
    if (impl_ptr()) {
        return impl_ptr<impl>()->source_node();
    }
    return node{nullptr};
}

audio::engine::node audio::engine::connection::destination_node() const {
    if (impl_ptr()) {
        return impl_ptr<impl>()->destination_node();
    }
    return node{nullptr};
}

audio::format const &audio::engine::connection::format() const {
    return impl_ptr<impl>()->_format;
}

audio::engine::node_removable &audio::engine::connection::node_removable() {
    if (!_node_removable) {
        _node_removable = audio::engine::node_removable{impl_ptr<node_removable::impl>()};
    }
    return _node_removable;
}
