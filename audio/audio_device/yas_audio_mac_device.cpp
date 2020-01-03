//
//  yas_audio_mac_device.cpp
//

#include "yas_audio_mac_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <cpp_utils/yas_cf_utils.h>
#include <mutex>
#include "yas_audio_mac_empty_device.h"
#include "yas_audio_mac_io_core.h"
#include "yas_audio_renewable_device.h"

#include <cpp_utils/yas_cf_utils.h>
#include <iostream>

using namespace yas;

namespace yas::audio {

static chaining::notifier_ptr<audio::mac_device::change_info> _system_notifier =
    chaining::notifier<audio::mac_device::change_info>::make_shared();

#pragma mark - utility

template <typename T>
static std::unique_ptr<std::vector<T>> _property_data(AudioObjectID const object_id,
                                                      AudioObjectPropertySelector const selector,
                                                      AudioObjectPropertyScope const scope) {
    AudioObjectPropertyAddress const address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    UInt32 byte_size = 0;
    raise_if_raw_audio_error(AudioObjectGetPropertyDataSize(object_id, &address, 0, nullptr, &byte_size));

    if (byte_size == 0) {
        return nullptr;
    }

    if (byte_size % sizeof(T)) {
        return nullptr;
    }

    uint32_t vector_size = byte_size / sizeof(T);

    auto data = std::make_unique<std::vector<T>>(vector_size);
    byte_size = vector_size * sizeof(T);
    raise_if_raw_audio_error(AudioObjectGetPropertyData(object_id, &address, 0, nullptr, &byte_size, data->data()));
    return data;
}

static std::unique_ptr<std::vector<uint8_t>> _property_byte_data(AudioObjectID const object_id,
                                                                 AudioObjectPropertySelector const selector,
                                                                 AudioObjectPropertyScope const scope) {
    AudioObjectPropertyAddress const address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    UInt32 byte_size = 0;
    raise_if_raw_audio_error(AudioObjectGetPropertyDataSize(object_id, &address, 0, nullptr, &byte_size));

    if (byte_size == 0) {
        return nullptr;
    }

    auto data = std::make_unique<std::vector<uint8_t>>(byte_size);
    raise_if_raw_audio_error(AudioObjectGetPropertyData(object_id, &address, 0, nullptr, &byte_size, data->data()));
    return data;
}

static CFStringRef _property_string(AudioObjectID const object_id, AudioObjectPropertySelector const selector) {
    AudioObjectPropertyAddress const address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    CFStringRef cfString = nullptr;
    UInt32 size = sizeof(CFStringRef);
    raise_if_raw_audio_error(AudioObjectGetPropertyData(object_id, &address, 0, nullptr, &size, &cfString));
    if (cfString) {
        return (CFStringRef)CFAutorelease(cfString);
    }

    return nullptr;
}

static void _add_listener(AudioObjectID const object_id, AudioObjectPropertySelector const selector,
                          AudioObjectPropertyScope const scope, audio::mac_device::listener_f const handler) {
    AudioObjectPropertyAddress const address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    raise_if_raw_audio_error(AudioObjectAddPropertyListenerBlock(
        object_id, &address, dispatch_get_main_queue(),
        ^(uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
            handler(address_count, addresses);
        }));
}

#pragma mark - mac_device_global

struct mac_device_global {
    struct global_mac_device : mac_device {
        static std::shared_ptr<global_mac_device> make_shared(AudioDeviceID const device_id) {
            auto shared = std::shared_ptr<global_mac_device>(new global_mac_device{device_id});
            shared->_prepare(shared);
            return shared;
        }

       private:
        global_mac_device(AudioDeviceID const device_id) : mac_device(device_id) {
        }
    };

    static std::unordered_map<AudioDeviceID, mac_device_ptr> &all_devices_map() {
        _initialize();
        return mac_device_global::instance()._all_devices;
    }

    static audio::mac_device::listener_f system_listener() {
        return [](uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
            update_all_devices();

            std::vector<mac_device::property_info> property_infos;
            for (uint32_t i = 0; i < address_count; i++) {
                property_infos.push_back(mac_device::property_info{.property = mac_device::property::system,
                                                                   .object_id = kAudioObjectSystemObject,
                                                                   .address = addresses[i]});
            }
            mac_device::change_info change_info{.property_infos = std::move(property_infos)};
            audio::_system_notifier->notify(change_info);
        };
    }

    static void update_all_devices() {
        auto prev_devices = std::move(all_devices_map());
        auto data = _property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDevices,
                                                  kAudioObjectPropertyScopeGlobal);
        if (data) {
            auto &map = all_devices_map();
            for (auto const &device_id : *data) {
                if (prev_devices.count(device_id) > 0) {
                    map.insert(std::make_pair(device_id, prev_devices.at(device_id)));
                } else {
                    map.insert(std::make_pair(device_id, global_mac_device::make_shared(device_id)));
                }
            }
        }
    }

   private:
    std::unordered_map<AudioDeviceID, mac_device_ptr> _all_devices;

    static void _initialize() {
        static bool once = false;
        if (!once) {
            once = true;

            update_all_devices();

            auto listener = system_listener();

            _add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
                          listener);
            _add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice,
                          kAudioObjectPropertyScopeGlobal, listener);
            _add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice,
                          kAudioObjectPropertyScopeGlobal, listener);
            _add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultInputDevice,
                          kAudioObjectPropertyScopeGlobal, listener);
        }
    }

    static mac_device_global &instance() {
        static mac_device_global _instance;
        return _instance;
    }

    mac_device_global() = default;

    mac_device_global(mac_device_global const &) = delete;
    mac_device_global(mac_device_global &&) = delete;
    mac_device_global &operator=(mac_device_global const &) = delete;
    mac_device_global &operator=(mac_device_global &&) = delete;
};
}  // namespace yas::audio

#pragma mark - property_info

bool audio::mac_device::property_info::operator<(mac_device::property_info const &info) const {
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

#pragma mark - global

std::vector<audio::mac_device_ptr> audio::mac_device::all_devices() {
    std::vector<mac_device_ptr> devices;
    for (auto &pair : mac_device_global::all_devices_map()) {
        devices.push_back(pair.second);
    }
    return devices;
}

std::vector<audio::mac_device_ptr> audio::mac_device::output_devices() {
    std::vector<mac_device_ptr> devices;
    for (auto &pair : mac_device_global::all_devices_map()) {
        if (pair.second->output_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::vector<audio::mac_device_ptr> audio::mac_device::input_devices() {
    std::vector<mac_device_ptr> devices;
    for (auto &pair : mac_device_global::all_devices_map()) {
        if (pair.second->input_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::optional<audio::mac_device_ptr> audio::mac_device::default_system_output_device() {
    if (auto const data =
            _property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice,
                                          kAudioObjectPropertyScopeGlobal)) {
        auto iterator = mac_device_global::all_devices_map().find(*data->data());
        if (iterator != mac_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return std::nullopt;
}

std::optional<audio::mac_device_ptr> audio::mac_device::default_output_device() {
    if (auto const data = _property_data<AudioDeviceID>(
            kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)) {
        auto iterator = mac_device_global::all_devices_map().find(*data->data());
        if (iterator != mac_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return std::nullopt;
}

std::optional<audio::mac_device_ptr> audio::mac_device::default_input_device() {
    if (auto const data = _property_data<AudioDeviceID>(
            kAudioObjectSystemObject, kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal)) {
        auto iterator = mac_device_global::all_devices_map().find(*data->data());
        if (iterator != mac_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return std::nullopt;
}

audio::io_device_ptr audio::mac_device::renewable_default_output_device() {
    return audio::renewable_device::make_shared(
        []() {
            io_device_ptr result = nullptr;
            if (auto const device = mac_device::default_output_device()) {
                result = device.value();
            } else {
                result = audio::mac_empty_device::make_shared();
            }
            return result;
        },
        [](io_device_ptr const &device, renewable_device::method_f const &handler) {
            auto pool = chaining::observer_pool::make_shared();

            *pool += device->io_device_chain()
                         .guard([](auto const &method) { return method == audio::io_device::method::updated; })
                         .perform([handler](auto const &) { handler(renewable_device::method::notify); })
                         .end();

            *pool += mac_device::system_chain()
                         .perform([handler](auto const &) { handler(renewable_device::method::renewal); })
                         .end();

            return pool;
        });
}

std::optional<audio::mac_device_ptr> audio::mac_device::device_for_id(AudioDeviceID const audio_device_id) {
    auto it = mac_device_global::all_devices_map().find(audio_device_id);
    if (it != mac_device_global::all_devices_map().end()) {
        return it->second;
    }
    return std::nullopt;
}

std::optional<size_t> audio::mac_device::index_of_device(mac_device_ptr const &device) {
    auto all_devices = mac_device::all_devices();
    auto it = std::find_if(all_devices.begin(), all_devices.end(), [&device](auto const &value) {
        return value->audio_device_id() == device->audio_device_id();
    });
    if (it != all_devices.end()) {
        return std::make_optional<size_t>(it - all_devices.begin());
    } else {
        return std::nullopt;
    }
}

bool audio::mac_device::is_available_device(mac_device_ptr const &device) {
    auto it = mac_device_global::all_devices_map().find(device->audio_device_id());
    return it != mac_device_global::all_devices_map().end();
}

#pragma mark - main

audio::mac_device::mac_device(AudioDeviceID const device_id)
    : _input_format(std::nullopt), _output_format(std::nullopt), _audio_device_id(device_id) {
    this->_udpate_streams(kAudioObjectPropertyScopeInput);
    this->_udpate_streams(kAudioObjectPropertyScopeOutput);
    this->_update_format(kAudioObjectPropertyScopeInput);
    this->_update_format(kAudioObjectPropertyScopeOutput);

    auto listener = this->_listener();
    _add_listener(device_id, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal, listener);
    _add_listener(device_id, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput, listener);
    _add_listener(device_id, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput, listener);
    _add_listener(device_id, kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeInput, listener);
    _add_listener(device_id, kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeOutput, listener);
}

void audio::mac_device::_prepare(mac_device_ptr const &mac_device) {
    this->_weak_mac_device = mac_device;

    this->_io_pool +=
        this->_notifier->chain().to_value(io_device::method::updated).send_to(this->_io_device_notifier).end();

    this->_io_pool += _system_notifier->chain()
                          .guard([weak_device = this->_weak_mac_device](auto const &pair) {
                              if (auto const device = weak_device.lock()) {
                                  if (!is_available_device(device)) {
                                      return true;
                                  }
                              }
                              return false;
                          })
                          .to_value(io_device::method::lost)
                          .send_to(this->_io_device_notifier)
                          .end();
}

AudioDeviceID audio::mac_device::audio_device_id() const {
    return this->_audio_device_id;
}

std::string audio::mac_device::name() const {
    return to_string(_property_string(this->audio_device_id(), kAudioObjectPropertyName));
}

std::string audio::mac_device::manufacture() const {
    return to_string(_property_string(this->audio_device_id(), kAudioObjectPropertyManufacturer));
}

std::vector<audio::mac_device::stream_ptr> audio::mac_device::input_streams() const {
    std::vector<stream_ptr> streams;
    for (auto &pair : this->_input_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

std::vector<audio::mac_device::stream_ptr> audio::mac_device::output_streams() const {
    std::vector<stream_ptr> streams;
    for (auto &pair : this->_output_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

double audio::mac_device::nominal_sample_rate() const {
    if (auto const data = _property_data<double>(audio_device_id(), kAudioDevicePropertyNominalSampleRate,
                                                 kAudioObjectPropertyScopeGlobal)) {
        return *data->data();
    }
    return 0;
}

void audio::mac_device::_set_input_format(std::optional<audio::format> const &format) {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    this->_input_format = format;
}

std::optional<audio::format> audio::mac_device::input_format() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return this->_input_format;
}

void audio::mac_device::_set_output_format(std::optional<audio::format> const &format) {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    this->_output_format = format;
}

std::optional<audio::format> audio::mac_device::output_format() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return this->_output_format;
}

std::optional<audio::interruptor_ptr> const &audio::mac_device::interruptor() const {
    static std::optional<interruptor_ptr> const _nullopt = std::nullopt;
    return _nullopt;
}

audio::io_core_ptr audio::mac_device::make_io_core() const {
    return mac_io_core::make_shared(this->_weak_mac_device.lock());
}

chaining::chain_unsync_t<audio::mac_device::change_info> audio::mac_device::chain() const {
    return this->_notifier->chain();
}

chaining::chain_unsync_t<audio::mac_device::change_info> audio::mac_device::system_chain() {
    return audio::_system_notifier->chain();
}

chaining::chain_unsync_t<audio::io_device::method> audio::mac_device::io_device_chain() {
    return this->_io_device_notifier->chain();
}

audio::mac_device::listener_f audio::mac_device::_listener() {
    AudioDeviceID const device_id = this->_audio_device_id;

    return [device_id](uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
        if (auto const device_opt = mac_device::device_for_id(device_id)) {
            auto const &device = *device_opt;
            AudioObjectID const object_id = device->audio_device_id();

            std::vector<mac_device::property_info> property_infos;
            for (uint32_t i = 0; i < address_count; ++i) {
                if (addresses[i].mSelector == kAudioDevicePropertyStreams) {
                    property_infos.emplace_back(
                        property_info{.property = property::stream, .object_id = object_id, .address = addresses[i]});
                } else if (addresses[i].mSelector == kAudioDevicePropertyStreamConfiguration) {
                    property_infos.emplace_back(
                        property_info{.property = property::format, .object_id = object_id, .address = addresses[i]});
                } else if (addresses[i].mSelector == kAudioDevicePropertyNominalSampleRate) {
                    if (addresses[i].mScope == kAudioObjectPropertyScopeGlobal) {
                        AudioObjectPropertyAddress address = addresses[i];
                        address.mScope = kAudioObjectPropertyScopeOutput;
                        property_infos.emplace_back(
                            property_info{.property = property::format, .object_id = object_id, .address = address});
                        address.mScope = kAudioObjectPropertyScopeInput;
                        property_infos.emplace_back(
                            property_info{.property = property::format, .object_id = object_id, .address = address});
                    }
                }
            }

            for (auto &info : property_infos) {
                switch (info.property) {
                    case property::stream:
                        device->_udpate_streams(info.address.mScope);
                        break;
                    case property::format:
                        device->_update_format(info.address.mScope);
                        break;
                    default:
                        break;
                }
            }

            mac_device::change_info change_info{std::move(property_infos)};
            device->_notifier->notify(change_info);
        }
    };
}

void audio::mac_device::_udpate_streams(AudioObjectPropertyScope const scope) {
    auto prev_streams =
        std::move((scope == kAudioObjectPropertyScopeInput) ? this->_input_streams_map : this->_output_streams_map);
    auto data = _property_data<AudioStreamID>(this->_audio_device_id, kAudioDevicePropertyStreams, scope);
    auto &new_streams =
        (scope == kAudioObjectPropertyScopeInput) ? this->_input_streams_map : this->_output_streams_map;
    if (data) {
        for (auto &stream_id : *data) {
            if (prev_streams.count(stream_id) > 0) {
                new_streams.insert(std::make_pair(stream_id, prev_streams.at(stream_id)));
            } else {
                new_streams.insert(std::make_pair(
                    stream_id,
                    audio::mac_device::stream::make_shared({.stream_id = stream_id, .device_id = _audio_device_id})));
            }
        }
    }
}

void audio::mac_device::_update_format(AudioObjectPropertyScope const scope) {
    stream_ptr stream = nullptr;

    if (scope == kAudioObjectPropertyScopeInput) {
        auto iterator = this->_input_streams_map.begin();
        if (iterator != this->_input_streams_map.end()) {
            stream = iterator->second;
            this->_set_input_format(std::nullopt);
        }
    } else if (scope == kAudioObjectPropertyScopeOutput) {
        auto iterator = this->_output_streams_map.begin();
        if (iterator != this->_output_streams_map.end()) {
            stream = iterator->second;
            this->_set_output_format(std::nullopt);
        }
    }

    if (!stream) {
        return;
    }

    auto stream_format = stream->virtual_format();

    auto data = _property_byte_data(this->_audio_device_id, kAudioDevicePropertyStreamConfiguration, scope);
    if (data) {
        uint32_t channel_count = 0;

        AudioBufferList *abl = reinterpret_cast<AudioBufferList *>(data->data());

        for (uint32_t i = 0; i < abl->mNumberBuffers; i++) {
            channel_count += abl->mBuffers[i].mNumberChannels;
        }

        audio::format format({.sample_rate = stream_format.sample_rate(),
                              .channel_count = channel_count,
                              .pcm_format = stream_format.pcm_format(),
                              .interleaved = false});

        if (scope == kAudioObjectPropertyScopeInput) {
            this->_set_input_format(format);
        } else if (scope == kAudioObjectPropertyScopeOutput) {
            this->_set_output_format(format);
        }
    }
}

bool audio::mac_device::operator==(mac_device const &rhs) const {
    return this->audio_device_id() == rhs.audio_device_id();
}

bool audio::mac_device::operator!=(mac_device const &rhs) const {
    return !(*this == rhs);
}

#endif
