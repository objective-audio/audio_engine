//
//  yas_audio_connection.cpp
//

#include "yas_audio_engine_connection.h"
#include <cpp_utils/yas_stl_utils.h>
#include <mutex>
#include "yas_audio_engine_node.h"

using namespace yas;

audio::engine::connection::connection(node &src_node, uint32_t const src_bus, node &dst_node, uint32_t const dst_bus,
                                      audio::format const &format)
    : source_bus(src_bus),
      destination_bus(dst_bus),
      format(format),
      _source_node(to_weak(src_node.shared_from_this())),
      _destination_node(to_weak(dst_node.shared_from_this())) {
}

audio::engine::connection::~connection() {
    if (auto node = this->_destination_node.lock()) {
        node->connectable()->remove_connection(*this);
    }
    if (auto node = this->_source_node.lock()) {
        node->connectable()->remove_connection(*this);
    }
}

std::shared_ptr<audio::engine::node> audio::engine::connection::source_node() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->_source_node.lock();
}

std::shared_ptr<audio::engine::node> audio::engine::connection::destination_node() const {
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

std::shared_ptr<audio::engine::node_removable> audio::engine::connection::removable() {
    return std::dynamic_pointer_cast<node_removable>(shared_from_this());
}

std::shared_ptr<audio::engine::connection> audio::engine::connection::make_shared(audio::engine::node &src_node,
                                                                                  uint32_t const src_bus,
                                                                                  audio::engine::node &dst_node,
                                                                                  uint32_t const dst_bus,
                                                                                  audio::format const &format) {
    auto connection = std::shared_ptr<audio::engine::connection>(
        new audio::engine::connection{src_node, src_bus, dst_node, dst_bus, format});
    src_node.connectable()->add_connection(*connection);
    dst_node.connectable()->add_connection(*connection);
    return connection;
}
