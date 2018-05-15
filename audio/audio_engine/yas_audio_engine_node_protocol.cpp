//
//  yas_audio_node_protocol.cpp
//

#include "yas_audio_engine_node_protocol.h"
#include "yas_audio_engine_manager.h"

using namespace yas;

#pragma mark - connectable_node

audio::engine::connectable_node::connectable_node(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::engine::connectable_node::connectable_node(std::nullptr_t) : protocol(nullptr) {
}

void audio::engine::connectable_node::add_connection(audio::engine::connection const &connection) {
    impl_ptr<impl>()->add_connection(connection);
}

void audio::engine::connectable_node::remove_connection(audio::engine::connection const &connection) {
    impl_ptr<impl>()->remove_connection(connection);
}

#pragma mark - manageable_node

audio::engine::manageable_node::manageable_node(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::engine::manageable_node::manageable_node(std::nullptr_t) : protocol(nullptr) {
}

audio::engine::connection audio::engine::manageable_node::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::engine::connection audio::engine::manageable_node::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::engine::connection_wmap const &audio::engine::manageable_node::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::engine::connection_wmap const &audio::engine::manageable_node::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

void audio::engine::manageable_node::set_manager(audio::engine::manager const &manager) {
    impl_ptr<impl>()->set_manager(manager);
}

audio::engine::manager audio::engine::manageable_node::manager() const {
    return impl_ptr<impl>()->manager();
}

void audio::engine::manageable_node::update_kernel() {
    impl_ptr<impl>()->update_kernel();
}

void audio::engine::manageable_node::update_connections() {
    impl_ptr<impl>()->update_connections();
}

void audio::engine::manageable_node::set_add_to_graph_handler(graph_editing_f handler) {
    impl_ptr<impl>()->set_add_to_graph_handler(std::move(handler));
}

void audio::engine::manageable_node::set_remove_from_graph_handler(graph_editing_f handler) {
    impl_ptr<impl>()->set_remove_from_graph_handler(std::move(handler));
}

audio::graph_editing_f const &audio::engine::manageable_node::add_to_graph_handler() const {
    return impl_ptr<impl>()->add_to_graph_handler();
}

audio::graph_editing_f const &audio::engine::manageable_node::remove_from_graph_handler() const {
    return impl_ptr<impl>()->remove_from_graph_handler();
}
