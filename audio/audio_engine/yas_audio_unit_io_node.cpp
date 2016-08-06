//
//  yas_audio_unit_io_node.cpp
//

#include "yas_audio_unit_io_node.h"
#include "yas_audio_unit_node.h"

#if TARGET_OS_IPHONE
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
#endif

using namespace yas;

#pragma mark - main

audio::unit_io_node::unit_io_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_io_node::unit_io_node() : unit_io_node(args{}) {
}

audio::unit_io_node::unit_io_node(args args) : base(std::make_shared<impl>(std::move(args))) {
    impl_ptr<impl>()->prepare(*this);
}

audio::unit_io_node::~unit_io_node() = default;

void audio::unit_io_node::set_channel_map(channel_map_t const &map, direction const dir) {
    impl_ptr<impl>()->set_channel_map(map, dir);
}

audio::channel_map_t const &audio::unit_io_node::channel_map(direction const dir) const {
    return impl_ptr<impl>()->channel_map(dir);
}

double audio::unit_io_node::device_sample_rate() const {
    return impl_ptr<impl>()->device_sample_rate();
}

uint32_t audio::unit_io_node::output_device_channel_count() const {
    return impl_ptr<impl>()->output_device_channel_count();
}

uint32_t audio::unit_io_node::input_device_channel_count() const {
    return impl_ptr<impl>()->input_device_channel_count();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::unit_io_node::set_device(audio::device const &device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::unit_io_node::device() const {
    return impl_ptr<impl>()->device();
}

#endif

audio::unit_io_node::subject_t &audio::unit_io_node::subject() {
    return impl_ptr<impl>()->subject();
}

audio::unit_node const &audio::unit_io_node::unit_node() const {
    return impl_ptr<impl>()->unit_node();
}

audio::unit_node &audio::unit_io_node::unit_node() {
    return impl_ptr<impl>()->unit_node();
}

#pragma mark - audio_unit_output_node

audio::unit_output_node::unit_output_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_output_node::unit_output_node() : base(std::make_unique<impl>()) {
}

void audio::unit_output_node::set_channel_map(channel_map_t const &map) {
    unit_io_node().set_channel_map(map, direction::output);
}

audio::channel_map_t const &audio::unit_output_node::channel_map() const {
    return unit_io_node().channel_map(direction::output);
}

audio::unit_io_node const &audio::unit_output_node::unit_io_node() const {
    return impl_ptr<impl>()->_unit_io_node;
}

audio::unit_io_node &audio::unit_output_node::unit_io_node() {
    return impl_ptr<impl>()->_unit_io_node;
}

#pragma mark - audio_unit_input_node

audio::unit_input_node::unit_input_node(std::nullptr_t) : base(nullptr) {
}

audio::unit_input_node::unit_input_node() : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

void audio::unit_input_node::set_channel_map(channel_map_t const &map) {
    unit_io_node().set_channel_map(map, direction::input);
}

audio::channel_map_t const &audio::unit_input_node::channel_map() const {
    return unit_io_node().channel_map(direction::input);
}

audio::unit_io_node const &audio::unit_input_node::unit_io_node() const {
    return impl_ptr<impl>()->_unit_io_node;
}

audio::unit_io_node &audio::unit_input_node::unit_io_node() {
    return impl_ptr<impl>()->_unit_io_node;
}
