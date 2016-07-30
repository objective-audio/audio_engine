//
//  yas_audio_device_io_node.cpp
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"

using namespace yas;

audio::device_io_node::device_io_node() : device_io_node(audio::device(nullptr)) {
}

audio::device_io_node::device_io_node(std::nullptr_t) : base(nullptr) {
}

audio::device_io_node::device_io_node(audio::device const &device) : base(std::make_unique<impl>()) {
    impl_ptr<impl>()->prepare(*this, device);
}

audio::device_io_node::device_io_node(std::shared_ptr<impl> const &impl) : base(impl) {
}

audio::device_io_node::~device_io_node() = default;

void audio::device_io_node::set_device(audio::device const &device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::device_io_node::device() const {
    return impl_ptr<impl>()->device();
}

audio::node const &audio::device_io_node::node() const {
    return impl_ptr<impl>()->node();
}

audio::node &audio::device_io_node::node() {
    return impl_ptr<impl>()->node();
}

audio::manageable_device_io_node &audio::device_io_node::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_device_io_node{impl_ptr<manageable_device_io_node::impl>()};
    }
    return _manageable;
}

#endif
