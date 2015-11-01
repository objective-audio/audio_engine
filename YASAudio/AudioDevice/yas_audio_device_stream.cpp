//
//  yas_audio_device_stream.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_stream.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"
#include "yas_audio_format.h"
#include <dispatch/dispatch.h>

using namespace yas;

using listener_f =
    std::function<void(const UInt32 in_number_addresses, const AudioObjectPropertyAddress *in_addresses)>;

#pragma mark - property_info

audio_device_stream::property_info::property_info(const audio_device_stream::property property,
                                                  const AudioObjectID object_id,
                                                  const AudioObjectPropertyAddress &address)
    : property(property), object_id(object_id), address(address)
{
}

bool audio_device_stream::property_info::operator<(const audio_device_stream::property_info &info) const
{
    if (property != info.property) {
        return property < info.property;
    }

    if (object_id != info.object_id) {
        return object_id < info.object_id;
    }

    if (address.mSelector != info.address.mSelector) {
        return address.mSelector < info.address.mSelector;
    }

    if (address.mScope != info.address.mScope) {
        return address.mScope < info.address.mScope;
    }

    return address.mElement < info.address.mElement;
}

#pragma mark - private

class audio_device_stream::impl : public base::impl
{
   public:
    AudioStreamID stream_id;
    AudioDeviceID device_id;
    yas::subject subject;

    impl(const AudioStreamID stream_id, const AudioDeviceID device_id)
        : stream_id(stream_id), device_id(device_id), subject()
    {
    }

    listener_f listener(const audio_device_stream &stream)
    {
        auto weak_stream = to_weak(stream);

        return [weak_stream](UInt32 address_count, const AudioObjectPropertyAddress *addresses) {
            if (auto stream = weak_stream.lock()) {
                const AudioStreamID object_id = stream.stream_id();
                auto infos = std::make_shared<std::set<property_info> >();
                for (UInt32 i = 0; i < address_count; i++) {
                    if (addresses[i].mSelector == kAudioStreamPropertyVirtualFormat) {
                        infos->insert(
                            property_info(audio_device_stream::property::virtual_format, object_id, addresses[i]));
                    } else if (addresses[i].mSelector == kAudioStreamPropertyIsActive) {
                        infos->insert(property_info(audio_device_stream::property::is_active, object_id, addresses[i]));
                    } else if (addresses[i].mSelector == kAudioStreamPropertyStartingChannel) {
                        infos->insert(
                            property_info(audio_device_stream::property::starting_channel, object_id, addresses[i]));
                    }
                }
                stream.subject().notify(audio_device_stream_method::stream_did_change, infos);
            }
        };
    }

    void add_listener(const AudioObjectPropertySelector &selector, listener_f function)
    {
        const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                    .mScope = kAudioObjectPropertyScopeGlobal,
                                                    .mElement = kAudioObjectPropertyElementMaster};

        yas_raise_if_au_error(
            AudioObjectAddPropertyListenerBlock(stream_id, &address, dispatch_get_main_queue(),
                                                ^(UInt32 address_count, const AudioObjectPropertyAddress *addresses) {
                                                    function(address_count, addresses);
                                                }));
    }
};

#pragma mark - main

audio_device_stream::audio_device_stream(std::nullptr_t) : super_class(nullptr)
{
}

audio_device_stream::audio_device_stream(const AudioStreamID stream_id, const AudioDeviceID device_id)
    : super_class(std::make_shared<impl>(stream_id, device_id))
{
    auto impl = _impl_ptr();
    auto function = impl->listener(*this);
    impl->add_listener(kAudioStreamPropertyVirtualFormat, function);
    impl->add_listener(kAudioStreamPropertyIsActive, function);
    impl->add_listener(kAudioStreamPropertyStartingChannel, function);
}

audio_device_stream::~audio_device_stream() = default;

bool audio_device_stream::operator==(const audio_device_stream &other)
{
    if (impl_ptr() && other.impl_ptr()) {
        return stream_id() == other.stream_id();
    }
    return false;
}

bool audio_device_stream::operator!=(const audio_device_stream &other)
{
    if (impl_ptr() && other.impl_ptr()) {
        return stream_id() != other.stream_id();
    }
    return true;
}

AudioStreamID audio_device_stream::stream_id() const
{
    return _impl_ptr()->stream_id;
}

audio_device audio_device_stream::device() const
{
    return audio_device::device_for_id(_impl_ptr()->device_id);
}

bool audio_device_stream::is_active() const
{
    auto data = _property_data<UInt32>(stream_id(), kAudioStreamPropertyIsActive);
    if (data) {
        return *data->data() > 0;
    }
    return false;
}

direction audio_device_stream::direction() const
{
    auto data = _property_data<UInt32>(stream_id(), kAudioStreamPropertyDirection);
    if (data) {
        if (*data->data() == 1) {
            return direction::input;
        }
    }
    return direction::output;
}

audio_format audio_device_stream::virtual_format() const
{
    auto data = _property_data<AudioStreamBasicDescription>(stream_id(), kAudioStreamPropertyVirtualFormat);
    if (!data) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : can't get virtual format.");
    }
    return audio_format(*data->data());
}

UInt32 audio_device_stream::starting_channel() const
{
    auto data = _property_data<UInt32>(stream_id(), kAudioStreamPropertyStartingChannel);
    if (data) {
        return *data->data();
    }
    return 0;
}

yas::subject &audio_device_stream::subject() const
{
    return _impl_ptr()->subject;
}

std::shared_ptr<audio_device_stream::impl> audio_device_stream::_impl_ptr() const
{
    return impl_ptr<impl>();
}

#endif
