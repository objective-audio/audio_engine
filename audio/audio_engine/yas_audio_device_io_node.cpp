//
//  yas_audio_device_io_node.cpp
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"

using namespace yas;

audio::device_io_node::device_io_node() : device_io_node(audio::device(nullptr)) {
}

audio::device_io_node::device_io_node(std::nullptr_t) : node(nullptr) {
}

audio::device_io_node::device_io_node(audio::device const &device) : node(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this, device);
}

audio::device_io_node::device_io_node(std::shared_ptr<impl> const &impl) : node(impl) {
}

audio::device_io_node::~device_io_node() = default;

void audio::device_io_node::set_device(audio::device const &device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::device_io_node::device() const {
    return impl_ptr<impl>()->device();
}

audio::manageable_device_io_node audio::device_io_node::manageable_device_io_node() {
    return audio::manageable_device_io_node{impl_ptr<manageable_device_io_node::impl>()};
}

#endif
