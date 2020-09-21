//
//  yas_audio_connection.cpp
//

#include "yas_audio_graph_connection.h"

#include <cpp_utils/yas_stl_utils.h>

#include <mutex>

#include "yas_audio_graph_node.h"

using namespace yas;

audio::graph_connection::graph_connection(graph_node_ptr const &src_node, uint32_t const src_bus,
                                          graph_node_ptr const &dst_node, uint32_t const dst_bus,
                                          audio::format const &format)
    : _source_bus(src_bus),
      _destination_bus(dst_bus),
      _format(format),
      _source_node(to_weak(src_node)),
      _destination_node(to_weak(dst_node)) {
}

audio::graph_connection::~graph_connection() {
    if (auto node = this->_destination_node.lock()) {
        connectable_graph_node::cast(node)->remove_input_connection(this->_destination_bus);
    }
    if (auto node = this->_source_node.lock()) {
        connectable_graph_node::cast(node)->remove_output_connection(this->_source_bus);
    }
}

uint32_t audio::graph_connection::source_bus() const {
    return this->_source_bus;
}

uint32_t audio::graph_connection::destination_bus() const {
    return this->_destination_bus;
}

audio::graph_node_ptr audio::graph_connection::source_node() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->_source_node.lock();
}

audio::graph_node_ptr audio::graph_connection::destination_node() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->_destination_node.lock();
}

audio::format const &audio::graph_connection::format() const {
    return this->_format;
}

void audio::graph_connection::remove_nodes() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->_source_node.reset();
    this->_destination_node.reset();
}

void audio::graph_connection::remove_source_node() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->_source_node.reset();
}

void audio::graph_connection::remove_destination_node() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->_destination_node.reset();
}

void audio::graph_connection::_prepare(graph_connection_ptr const &shared) {
    this->_weak_connection = shared;
}

audio::graph_connection_ptr audio::graph_connection::make_shared(audio::graph_node_ptr const &src_node,
                                                                 uint32_t const src_bus,
                                                                 audio::graph_node_ptr const &dst_node,
                                                                 uint32_t const dst_bus, audio::format const &format) {
    auto shared = graph_connection_ptr(new audio::graph_connection{src_node, src_bus, dst_node, dst_bus, format});
    shared->_prepare(shared);
    connectable_graph_node::cast(src_node)->add_connection(shared);
    connectable_graph_node::cast(dst_node)->add_connection(shared);
    return shared;
}
