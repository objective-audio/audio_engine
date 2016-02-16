//
//  yas_audio_tap_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_tap_node.h"

using namespace yas;

audio::tap_node::tap_node() : super_class(std::make_unique<impl>()) {
}

audio::tap_node::tap_node(std::nullptr_t) : super_class(nullptr) {
}

audio::tap_node::tap_node(std::shared_ptr<impl> const &impl) : super_class(impl) {
}

audio::tap_node::~tap_node() = default;

void audio::tap_node::set_render_function(render_f const &func) {
    impl_ptr<impl>()->set_render_function(func);
}

audio::connection audio::tap_node::input_connection_on_render(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->input_connection_on_render(bus_idx);
}

audio::connection audio::tap_node::output_connection_on_render(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->output_connection_on_render(bus_idx);
}

audio::connection_smap audio::tap_node::input_connections_on_render() const {
    return impl_ptr<impl>()->input_connections_on_render();
}

audio::connection_smap audio::tap_node::output_connections_on_render() const {
    return impl_ptr<impl>()->output_connections_on_render();
}

void audio::tap_node::render_source(pcm_buffer &buffer, UInt32 const bus_idx, time const &when) {
    impl_ptr<impl>()->render_source(buffer, bus_idx, when);
}

#pragma mark - input_tap_node

audio::input_tap_node::input_tap_node() : super_class(std::make_unique<impl>()) {
}

audio::input_tap_node::input_tap_node(std::nullptr_t) : super_class(nullptr) {
}
