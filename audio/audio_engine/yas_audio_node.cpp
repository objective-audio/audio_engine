//
//  yas_audio_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_connection.h"
#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_time.h"

using namespace yas;

audio::node::node(std::nullptr_t) : super_class(nullptr) {
}

audio::node::node(std::shared_ptr<impl> const &impl) : super_class(impl) {
}

audio::node::~node() = default;

void audio::node::reset() {
    if (!impl_ptr()) {
        std::cout << "_impl is null" << std::endl;
    }
    impl_ptr<impl>()->reset();
}

audio::format audio::node::input_format(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->input_format(bus_idx);
}

audio::format audio::node::output_format(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->output_format(bus_idx);
}

audio::bus_result_t audio::node::next_available_input_bus() const {
    return impl_ptr<impl>()->next_available_input_bus();
}

audio::bus_result_t audio::node::next_available_output_bus() const {
    return impl_ptr<impl>()->next_available_output_bus();
}

bool audio::node::is_available_input_bus(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->is_available_input_bus(bus_idx);
}

bool audio::node::is_available_output_bus(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->is_available_output_bus(bus_idx);
}

audio::engine audio::node::engine() const {
    return impl_ptr<impl>()->engine();
}

audio::time audio::node::last_render_time() const {
    return impl_ptr<impl>()->render_time();
}

UInt32 audio::node::input_bus_count() const {
    return impl_ptr<impl>()->input_bus_count();
}

UInt32 audio::node::output_bus_count() const {
    return impl_ptr<impl>()->output_bus_count();
}

#pragma mark render thread

void audio::node::render(pcm_buffer &buffer, UInt32 const bus_idx, const time &when) {
    impl_ptr<impl>()->render(buffer, bus_idx, when);
}

void audio::node::set_render_time_on_render(const time &time) {
    impl_ptr<impl>()->set_render_time_on_render(time);
}

#pragma mark - private

audio::connection audio::node::_input_connection(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio::connection audio::node::_output_connection(UInt32 const bus_idx) const {
    return impl_ptr<impl>()->output_connection(bus_idx);
}

audio::connection_wmap const &audio::node::_input_connections() const {
    return impl_ptr<impl>()->input_connections();
}

audio::connection_wmap const &audio::node::_output_connections() const {
    return impl_ptr<impl>()->output_connections();
}

void audio::node::_add_connection(connection const &connection) {
    impl_ptr<impl>()->add_connection(connection);
}

void audio::node::_remove_connection(connection const &connection) {
    impl_ptr<impl>()->remove_connection(connection);
}

void audio::node::_set_engine(audio::engine const &engine) {
    impl_ptr<impl>()->set_engine(engine);
}

audio::engine audio::node::_engine() const {
    return impl_ptr<impl>()->engine();
}

void audio::node::_update_kernel() {
    impl_ptr<impl>()->update_kernel();
}

void audio::node::_update_connections() {
    impl_ptr<impl>()->update_connections();
}
