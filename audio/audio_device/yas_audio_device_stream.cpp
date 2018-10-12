//
//  yas_audio_device_stream.cpp
//

#include "yas_audio_device.h"

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

#pragma mark - private

struct audio::device::stream::impl : base::impl {
    using listener_f =
        std::function<void(uint32_t const in_number_addresses, const AudioObjectPropertyAddress *const in_addresses)>;

   public:
    AudioStreamID _stream_id;
    AudioDeviceID _device_id;
    chaining::notifier<chaining_pair_t> _notifier;

    impl(AudioStreamID const stream_id, AudioDeviceID const device_id) : _stream_id(stream_id), _device_id(device_id) {
    }

    bool is_equal(std::shared_ptr<base::impl> const &rhs) const override {
        if (auto casted_rhs = std::dynamic_pointer_cast<audio::device::stream::impl>(rhs)) {
            return this->_stream_id == casted_rhs->_stream_id;
        }
        return false;
    }

    listener_f listener(stream const &stream) {
        auto weak_stream = to_weak(stream);

        return [weak_stream](uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
            if (auto stream = weak_stream.lock()) {
                AudioStreamID const object_id = stream.stream_id();
                std::vector<property_info> infos;
                for (uint32_t i = 0; i < address_count; i++) {
                    if (addresses[i].mSelector == kAudioStreamPropertyVirtualFormat) {
                        infos.emplace_back(property_info{.property = stream::property::virtual_format,
                                                         .object_id = object_id,
                                                         .address = addresses[i]});
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
                stream.impl_ptr<impl>()->_notifier.notify(std::make_pair(method::did_change, change_info));
            }
        };
    }

    void add_listener(AudioObjectPropertySelector const &selector, listener_f handler) {
        AudioObjectPropertyAddress const address = {.mSelector = selector,
                                                    .mScope = kAudioObjectPropertyScopeGlobal,
                                                    .mElement = kAudioObjectPropertyElementMaster};

        raise_if_raw_audio_error(
            AudioObjectAddPropertyListenerBlock(this->_stream_id, &address, dispatch_get_main_queue(),
                                                ^(uint32_t address_count, const AudioObjectPropertyAddress *addresses) {
                                                    handler(address_count, addresses);
                                                }));
    }
};

#pragma mark - main

audio::device::stream::stream(args args) : base(std::make_shared<impl>(args.stream_id, args.device_id)) {
    auto imp = impl_ptr<impl>();
    auto listener = imp->listener(*this);
    imp->add_listener(kAudioStreamPropertyVirtualFormat, listener);
    imp->add_listener(kAudioStreamPropertyIsActive, listener);
    imp->add_listener(kAudioStreamPropertyStartingChannel, listener);
}

audio::device::stream::stream(std::nullptr_t) : base(nullptr) {
}

AudioStreamID audio::device::stream::stream_id() const {
    return impl_ptr<impl>()->_stream_id;
}

audio::device audio::device::stream::device() const {
    return device::device_for_id(impl_ptr<impl>()->_device_id);
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
    return impl_ptr<impl>()->_notifier.chain();
}

chaining::chain<audio::device::stream::change_info, audio::device::stream::chaining_pair_t,
                audio::device::stream::chaining_pair_t, false>
audio::device::stream::chain(method const method) const {
    return impl_ptr<impl>()
        ->_notifier.chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](audio::device::stream::chaining_pair_t const &pair) { return pair.second; });
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
