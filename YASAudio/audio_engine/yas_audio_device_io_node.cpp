//
//  yas_audio_device_io_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"

using namespace yas;

audio::device_io_node::device_io_node() : device_io_node(audio::device(nullptr))
{
}

audio::device_io_node::device_io_node(std::nullptr_t) : super_class(nullptr)
{
}

audio::device_io_node::device_io_node(const audio::device &device) : node(std::make_unique<device_io_node::impl>())
{
    impl_ptr<impl>()->prepare(*this, device);
}

audio::device_io_node::device_io_node(const std::shared_ptr<device_io_node::impl> &impl) : super_class(impl)
{
}

audio::device_io_node::~device_io_node() = default;

void audio::device_io_node::set_device(const audio::device &device)
{
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::device_io_node::device() const
{
    return impl_ptr<impl>()->device();
}

#pragma mark - private

void audio::device_io_node::_add_device_io()
{
    impl_ptr<impl>()->add_device_io();
}

void audio::device_io_node::_remove_device_io()
{
    impl_ptr<impl>()->remove_device_io();
}

audio::device_io &audio::device_io_node::_device_io() const
{
    return impl_ptr<impl>()->device_io();
}

#endif
