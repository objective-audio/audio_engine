//
//  yas_audio_device_stream.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

using namespace yas;

using listener_f =
    std::function<void(const UInt32 in_number_addresses, const AudioObjectPropertyAddress *in_addresses)>;

#pragma mark - property_info

audio::device::stream::property_info::property_info(const stream::property property, const AudioObjectID object_id,
                                                    const AudioObjectPropertyAddress &address)
    : property(property), object_id(object_id), address(address)
{
}

bool audio::device::stream::property_info::operator<(const property_info &info) const
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

#pragma mark - change_info

audio::device::stream::change_info::change_info(std::vector<property_info> &&infos) : property_infos(infos)
{
}

#pragma mark - private

class audio::device::stream::impl : public base::impl
{
   public:
    AudioStreamID stream_id;
    AudioDeviceID device_id;
    yas::subject<change_info> subject;

    impl(const AudioStreamID stream_id, const AudioDeviceID device_id)
        : stream_id(stream_id), device_id(device_id), subject()
    {
    }

    listener_f listener(const stream &stream)
    {
        auto weak_stream = to_weak(stream);

        return [weak_stream](UInt32 address_count, const AudioObjectPropertyAddress *addresses) {
            if (auto stream = weak_stream.lock()) {
                const AudioStreamID object_id = stream.stream_id();
                std::vector<property_info> infos;
                for (UInt32 i = 0; i < address_count; i++) {
                    if (addresses[i].mSelector == kAudioStreamPropertyVirtualFormat) {
                        infos.push_back(property_info(stream::property::virtual_format, object_id, addresses[i]));
                    } else if (addresses[i].mSelector == kAudioStreamPropertyIsActive) {
                        infos.push_back(property_info(stream::property::is_active, object_id, addresses[i]));
                    } else if (addresses[i].mSelector == kAudioStreamPropertyStartingChannel) {
                        infos.push_back(property_info(stream::property::starting_channel, object_id, addresses[i]));
                    }
                }
                change_info change_info{std::move(infos)};
                stream.subject().notify(stream::stream_did_change_key, change_info);
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

audio::device::stream::stream(std::nullptr_t) : super_class(nullptr)
{
}

audio::device::stream::stream(const AudioStreamID stream_id, const AudioDeviceID device_id)
    : super_class(std::make_shared<impl>(stream_id, device_id))
{
    auto imp = impl_ptr<impl>();
    auto function = imp->listener(*this);
    imp->add_listener(kAudioStreamPropertyVirtualFormat, function);
    imp->add_listener(kAudioStreamPropertyIsActive, function);
    imp->add_listener(kAudioStreamPropertyStartingChannel, function);
}

audio::device::stream::~stream() = default;

bool audio::device::stream::operator==(const stream &rhs) const
{
    if (impl_ptr() && rhs.impl_ptr()) {
        return stream_id() == rhs.stream_id();
    }
    return false;
}

bool audio::device::stream::operator!=(const stream &rhs) const
{
    if (impl_ptr() && rhs.impl_ptr()) {
        return stream_id() != rhs.stream_id();
    }
    return true;
}

AudioStreamID audio::device::stream::stream_id() const
{
    return impl_ptr<impl>()->stream_id;
}

audio::device audio::device::stream::device() const
{
    return device::device_for_id(impl_ptr<impl>()->device_id);
}

bool audio::device::stream::is_active() const
{
    auto data = _property_data<UInt32>(stream_id(), kAudioStreamPropertyIsActive);
    if (data) {
        return *data->data() > 0;
    }
    return false;
}

audio::direction audio::device::stream::direction() const
{
    auto data = _property_data<UInt32>(stream_id(), kAudioStreamPropertyDirection);
    if (data) {
        if (*data->data() == 1) {
            return direction::input;
        }
    }
    return direction::output;
}

audio::format audio::device::stream::virtual_format() const
{
    auto data = _property_data<AudioStreamBasicDescription>(stream_id(), kAudioStreamPropertyVirtualFormat);
    if (!data) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : can't get virtual format.");
    }
    return audio::format(*data->data());
}

UInt32 audio::device::stream::starting_channel() const
{
    auto data = _property_data<UInt32>(stream_id(), kAudioStreamPropertyStartingChannel);
    if (data) {
        return *data->data();
    }
    return 0;
}

yas::subject<yas::audio::device::stream::change_info> &audio::device::stream::subject() const
{
    return impl_ptr<impl>()->subject;
}

#endif
