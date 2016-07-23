//
//  yas_audio_node_protocol.cpp
//

#include "yas_audio_engine.h"
#include "yas_audio_node_protocol.h"

using namespace yas;

#pragma mark - connectable_node

audio::connectable_node::connectable_node(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::connectable_node::connectable_node(std::nullptr_t) : protocol(nullptr) {
}

void audio::connectable_node::add_connection(audio::connection const &connection) {
    impl_ptr<impl>()->add_connection(connection);
}

void audio::connectable_node::remove_connection(audio::connection const &connection) {
    impl_ptr<impl>()->remove_connection(connection);
}

#pragma mark - manageable_node

audio::manageable_node::manageable_node(std::shared_ptr<impl> impl) : connectable_node(std::move(impl)) {
}

audio::manageable_node::manageable_node(std::nullptr_t) : connectable_node(nullptr) {
}

audio::connection audio::manageable_node::input_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::connection audio::manageable_node::output_connection(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::connection_wmap const &audio::manageable_node::input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::connection_wmap const &audio::manageable_node::output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

void audio::manageable_node::set_engine(audio::engine const &engine) {
    impl_ptr<impl>()->set_engine(engine);
}

audio::engine audio::manageable_node::engine() const {
    return impl_ptr<impl>()->engine();
}

void audio::manageable_node::update_kernel() {
    impl_ptr<impl>()->update_kernel();
}

void audio::manageable_node::update_connections() {
    impl_ptr<impl>()->update_connections();
}
