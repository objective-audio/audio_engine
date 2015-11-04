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
    impl_ptr<impl>()->prepare(*this, device);
}

audio_device_io_node::audio_device_io_node(const std::shared_ptr<audio_device_io_node::impl> &impl) : super_class(impl)
{
}

audio_device_io_node::~audio_device_io_node() = default;

void audio_device_io_node::set_device(const audio_device &device)
{
    impl_ptr<impl>()->set_device(device);
}

audio_device audio_device_io_node::device() const
{
    return impl_ptr<impl>()->device();
}

#pragma mark - private

void audio_device_io_node::_add_audio_device_io_to_graph(audio_graph &graph)
{
    impl_ptr<impl>()->add_device_io_to_graph(graph);
}

void audio_device_io_node::_remove_audio_device_io_from_graph()
{
    impl_ptr<impl>()->remove_device_io_from_graph();
}

#endif
