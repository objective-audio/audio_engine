//
//  yas_audio_connection.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_connection.h"
#include "yas_audio_node.h"
#include <mutex>

using namespace yas;

class audio::connection::impl : public base::impl {
   public:
    UInt32 source_bus;

    UInt32 destination_bus;
    audio::format format;
    mutable std::recursive_mutex mutex;

    impl(const node &source_node, const UInt32 source_bus, const node &destination_node, const UInt32 destination_bus,
         const audio::format &format)
        : source_bus(source_bus),
          destination_bus(destination_bus),
          format(format),
          _source_node(source_node),
          _destination_node(destination_node) {
    }

    void remove_connection_from_nodes(const connection &connection) {
        if (auto node = _destination_node.lock()) {
            static_cast<node_from_connection &>(node)._remove_connection(connection);
        }
        if (auto node = _source_node.lock()) {
            static_cast<node_from_connection &>(node)._remove_connection(connection);
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

audio::connection::connection(std::nullptr_t) : super_class(nullptr) {
}

audio::connection::~connection() {
    if (impl_ptr() && impl_ptr().unique()) {
        if (auto imp = impl_ptr<impl>()) {
            imp->remove_connection_from_nodes(*this);
        }
        impl_ptr().reset();
    }
}

audio::connection::connection(node &source_node, const UInt32 source_bus, node &destination_node,
                              const UInt32 destination_bus, const audio::format &format)
    : super_class(std::make_shared<impl>(source_node, source_bus, destination_node, destination_bus, format)) {
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument.");
    }

    static_cast<node_from_connection &>(source_node)._add_connection(*this);
    static_cast<node_from_connection &>(destination_node)._add_connection(*this);
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

const audio::format &audio::connection::format() const {
    return impl_ptr<impl>()->format;
}

void audio::connection::_remove_nodes() {
    impl_ptr<impl>()->remove_nodes();
}

void audio::connection::_remove_source_node() {
    impl_ptr<impl>()->remove_source_node();
}

void audio::connection::_remove_destination_node() {
    impl_ptr<impl>()->remove_destination_node();
}
