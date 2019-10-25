//
//  yas_audio_connection.cpp
//

#include "yas_audio_engine_connection.h"
#include <cpp_utils/yas_stl_utils.h>
#include <mutex>
#include "yas_audio_engine_node.h"

using namespace yas;

audio::engine::connection::connection(node_ptr const &src_node, uint32_t const src_bus, node_ptr const &dst_node,
                                      uint32_t const dst_bus, audio::format const &format)
    : source_bus(src_bus),
      destination_bus(dst_bus),
      format(format),
      _source_node(to_weak(src_node)),
      _destination_node(to_weak(dst_node)) {
}

audio::engine::connection::~connection() {
    if (auto node = this->_destination_node.lock()) {
        connectable_node::cast(node)->remove_input_connection(this->destination_bus);
    }
    if (auto node = this->_source_node.lock()) {
        connectable_node::cast(node)->remove_output_connection(this->source_bus);
    }
}

audio::engine::node_ptr audio::engine::connection::source_node() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->_source_node.lock();
}

audio::engine::node_ptr audio::engine::connection::destination_node() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->_destination_node.lock();
}

void audio::engine::connection::remove_nodes() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->_source_node.reset();
    this->_destination_node.reset();
}

void audio::engine::connection::remove_source_node() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->_source_node.reset();
}

void audio::engine::connection::remove_destination_node() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->_destination_node.reset();
}

audio::engine::node_removable_ptr audio::engine::connection::removable() {
    return std::dynamic_pointer_cast<node_removable>(this->_weak_connection.lock());
}

void audio::engine::connection::_prepare(connection_ptr const &shared) {
    this->_weak_connection = shared;
}

audio::engine::connection_ptr audio::engine::connection::make_shared(audio::engine::node_ptr const &src_node,
                                                                     uint32_t const src_bus,
                                                                     audio::engine::node_ptr const &dst_node,
                                                                     uint32_t const dst_bus,
                                                                     audio::format const &format) {
    auto shared = connection_ptr(new audio::engine::connection{src_node, src_bus, dst_node, dst_bus, format});
    shared->_prepare(shared);
    connectable_node::cast(src_node)->add_connection(shared);
    connectable_node::cast(dst_node)->add_connection(shared);
    return shared;
}
