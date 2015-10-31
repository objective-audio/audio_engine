//
//  yas_audio_device_io_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_io_node.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"

using namespace yas;

audio_device_io_node::audio_device_io_node() : audio_device_io_node(audio_device(nullptr))
{
}

audio_device_io_node::audio_device_io_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_device_io_node::audio_device_io_node(const audio_device &device)
    : audio_node(std::make_unique<audio_device_io_node::impl>())
{
    _impl_ptr()->prepare(*this, device);
}

audio_device_io_node::audio_device_io_node(const std::shared_ptr<audio_device_io_node::impl> &impl) : super_class(impl)
{
}

audio_device_io_node::~audio_device_io_node() = default;

void audio_device_io_node::set_device(const audio_device &device)
{
    _impl_ptr()->set_device(device);
}

audio_device audio_device_io_node::device() const
{
    return _impl_ptr()->device();
}

#pragma mark - private

std::shared_ptr<audio_device_io_node::impl> audio_device_io_node::_impl_ptr() const
{
    return impl_ptr<impl>();
}

#endif
