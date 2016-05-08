//
//  yas_audio_connection.cpp
//

#include <mutex>
#include "yas_audio_connection.h"
#include "yas_audio_node.h"

using namespace yas;

struct audio::connection::impl : base::impl, node_removable::impl {
    UInt32 source_bus;
    UInt32 destination_bus;
    audio::format format;
    mutable std::recursive_mutex mutex;

    impl(node const &source_node, UInt32 const source_bus, node const &destination_node, UInt32 const destination_bus,
         audio::format const &format)
        : source_bus(source_bus),
          destination_bus(destination_bus),
          format(format),
          _source_node(source_node),
          _destination_node(destination_node) {
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
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return _source_node.lock();
    }

    node destination_node() const {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return _destination_node.lock();
    }

    void remove_nodes() {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        _source_node.reset();
        _destination_node.reset();
    }

    void remove_source_node() {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        _source_node.reset();
    }

    void remove_destination_node() {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        _destination_node.reset();
    }

   private:
    weak<node> _source_node;
    weak<node> _destination_node;
};

audio::connection::connection(std::nullptr_t) : base(nullptr) {
}

audio::connection::~connection() {
    if (impl_ptr() && impl_ptr().unique()) {
        if (auto imp = impl_ptr<impl>()) {
            imp->remove_connection_from_nodes(*this);
        }
        impl_ptr().reset();
    }
}

audio::connection::connection(node &source_node, UInt32 const source_bus, node &destination_node,
                              UInt32 const destination_bus, audio::format const &format)
    : base(std::make_shared<impl>(source_node, source_bus, destination_node, destination_bus, format)) {
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }

    source_node.connectable().add_connection(*this);
    destination_node.connectable().add_connection(*this);
}

UInt32 audio::connection::source_bus() const {
    return impl_ptr<impl>()->source_bus;
}

UInt32 audio::connection::destination_bus() const {
    return impl_ptr<impl>()->destination_bus;
}

audio::node audio::connection::source_node() const {
    if (impl_ptr()) {
        return impl_ptr<impl>()->source_node();
    }
    return node{nullptr};
}

audio::node audio::connection::destination_node() const {
    if (impl_ptr()) {
        return impl_ptr<impl>()->destination_node();
    }
    return node{nullptr};
}

audio::format const &audio::connection::format() const {
    return impl_ptr<impl>()->format;
}

audio::node_removable audio::connection::node_removable() {
    return audio::node_removable{impl_ptr<node_removable::impl>()};
}
