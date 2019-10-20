//
//  yas_audio_mac_device_stream.cpp
//

#include "yas_audio_mac_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_format.h"

using namespace yas;

#pragma mark - property_info

bool audio::device::stream::property_info::operator<(property_info const &info) const {
    if (this->property != info.property) {
        return this->property < info.property;
    }

    if (this->object_id != info.object_id) {
        return this->object_id < info.object_id;
    }

    if (this->address.mSelector != info.address.mSelector) {
        return this->address.mSelector < info.address.mSelector;
    }

    if (this->address.mScope != info.address.mScope) {
        return this->address.mScope < info.address.mScope;
    }

    return this->address.mElement < info.address.mElement;
}

#pragma mark - change_info

audio::device::stream::change_info::change_info(std::vector<property_info> &&infos) : property_infos(infos) {
}

#pragma mark - main

audio::device::stream::stream(args &&args) : _stream_id(args.stream_id), _device_id(args.device_id) {
}

AudioStreamID audio::device::stream::stream_id() const {
    return this->_stream_id;
}

std::optional<audio::device_ptr> audio::device::stream::device() const {
    return device::device_for_id(this->_device_id);
}

bool audio::device::stream::is_active() const {
    auto data = this->_property_data<uint32_t>(stream_id(), kAudioStreamPropertyIsActive);
    if (data) {
        return *data->data() > 0;
    }
    return false;
}

audio::direction audio::device::stream::direction() const {
    auto data = this->_property_data<uint32_t>(stream_id(), kAudioStreamPropertyDirection);
    if (data) {
        if (*data->data() == 1) {
            return direction::input;
        }
    }
    return direction::output;
}

audio::format audio::device::stream::virtual_format() const {
    auto data = this->_property_data<AudioStreamBasicDescription>(stream_id(), kAudioStreamPropertyVirtualFormat);
    if (!data) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : can't get virtual format.");
    }
    return audio::format(*data->data());
}

uint32_t audio::device::stream::starting_channel() const {
    auto data = this->_property_data<uint32_t>(stream_id(), kAudioStreamPropertyStartingChannel);
    if (data) {
        return *data->data();
    }
    return 0;
}

chaining::chain_unsync_t<audio::device::stream::chaining_pair_t> audio::device::stream::chain() const {
    return this->_notifier->chain();
}

chaining::chain_relayed_unsync_t<audio::device::stream::change_info, audio::device::stream::chaining_pair_t>
audio::device::stream::chain(method const method) const {
    return this->_notifier->chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](audio::device::stream::chaining_pair_t const &pair) { return pair.second; });
}

bool audio::device::stream::operator==(stream const &rhs) const {
    return this->stream_id() == rhs.stream_id();
}

bool audio::device::stream::operator!=(stream const &rhs) const {
    return !(*this == rhs);
}

void audio::device::stream::_prepare(device::stream_ptr const &shared) {
    this->_weak_stream = shared;

    auto listener = this->_listener();
    this->_add_listener(kAudioStreamPropertyVirtualFormat, listener);
    this->_add_listener(kAudioStreamPropertyIsActive, listener);
    this->_add_listener(kAudioStreamPropertyStartingChannel, listener);
}

audio::device::stream::listener_f audio::device::stream::_listener() {
    auto weak_stream = to_weak(this->_weak_stream.lock());

    return [weak_stream](uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
        if (auto stream = weak_stream.lock()) {
            AudioStreamID const object_id = stream->stream_id();
            std::vector<property_info> infos;
            for (uint32_t i = 0; i < address_count; i++) {
                if (addresses[i].mSelector == kAudioStreamPropertyVirtualFormat) {
                    infos.emplace_back(property_info{
                        .property = stream::property::virtual_format, .object_id = object_id, .address = addresses[i]});
                } else if (addresses[i].mSelector == kAudioStreamPropertyIsActive) {
                    infos.emplace_back(property_info{
                        .property = stream::property::is_active, .object_id = object_id, .address = addresses[i]});
                } else if (addresses[i].mSelector == kAudioStreamPropertyStartingChannel) {
                    infos.emplace_back(property_info{.property = stream::property::starting_channel,
                                                     .object_id = object_id,
                                                     .address = addresses[i]});
                }
            }
            change_info change_info{std::move(infos)};
            stream->_notifier->notify(std::make_pair(method::did_change, change_info));
        }
    };
}

void audio::device::stream::_add_listener(AudioObjectPropertySelector const &selector, listener_f handler) {
    AudioObjectPropertyAddress const address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    raise_if_raw_audio_error(
        AudioObjectAddPropertyListenerBlock(this->_stream_id, &address, dispatch_get_main_queue(),
                                            ^(uint32_t address_count, const AudioObjectPropertyAddress *addresses) {
                                                handler(address_count, addresses);
                                            }));
}

audio::device::stream_ptr audio::device::stream::make_shared(device::stream::args args) {
    auto shared = device::stream_ptr(new device::stream{std::move(args)});
    shared->_prepare(shared);
    return shared;
}

std::string yas::to_string(audio::device::stream::method const &method) {
    switch (method) {
        case audio::device::stream::method::did_change:
            return "did_change";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::device::stream::method const &value) {
    os << to_string(value);
    return os;
}

#endif
