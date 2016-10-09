//
//  yas_audio_device_io_node_protocol.cpp
//

#include "yas_audio_device_io_node_protocol.h"

using namespace yas;

audio::engine::manageable_device_io_node::manageable_device_io_node(std::shared_ptr<impl> impl)
    : protocol(std::move(impl)) {
}

audio::engine::manageable_device_io_node::manageable_device_io_node(std::nullptr_t) : protocol(nullptr) {
}

void audio::engine::manageable_device_io_node::add_device_io() {
    impl_ptr<impl>()->add_device_io();
}

void audio::engine::manageable_device_io_node::remove_device_io() {
    impl_ptr<impl>()->remove_device_io();
}

audio::device_io &audio::engine::manageable_device_io_node::device_io() const {
    return impl_ptr<impl>()->device_io();
}
