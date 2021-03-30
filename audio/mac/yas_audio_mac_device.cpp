//
//  yas_audio_mac_device.cpp
//

#include "yas_audio_mac_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <cpp_utils/yas_cf_utils.h>

#include "yas_audio_mac_empty_device.h"
#include "yas_audio_mac_io_core.h"
#include "yas_audio_renewable_device.h"

using namespace yas;
using namespace yas::audio;

namespace yas::audio {

static observing::notifier_ptr<mac_device::change_info> _system_notifier =
    observing::notifier<mac_device::change_info>::make_shared();

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
                          AudioObjectPropertyScope const scope, mac_device::listener_f const handler) {
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

    static mac_device::listener_f system_listener() {
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

bool mac_device::property_info::operator<(mac_device::property_info const &info) const {
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

std::vector<mac_device_ptr> mac_device::all_devices() {
    std::vector<mac_device_ptr> devices;
    for (auto &pair : mac_device_global::all_devices_map()) {
        devices.push_back(pair.second);
    }
    return devices;
}

std::vector<mac_device_ptr> mac_device::output_devices() {
    std::vector<mac_device_ptr> devices;
    for (auto &pair : mac_device_global::all_devices_map()) {
        if (pair.second->output_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::vector<mac_device_ptr> mac_device::input_devices() {
    std::vector<mac_device_ptr> devices;
    for (auto &pair : mac_device_global::all_devices_map()) {
        if (pair.second->input_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::optional<mac_device_ptr> mac_device::default_system_output_device() {
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

std::optional<mac_device_ptr> mac_device::default_output_device() {
    if (auto const data = _property_data<AudioDeviceID>(
            kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)) {
        auto iterator = mac_device_global::all_devices_map().find(*data->data());
        if (iterator != mac_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return std::nullopt;
}

std::optional<mac_device_ptr> mac_device::default_input_device() {
    if (auto const data = _property_data<AudioDeviceID>(
            kAudioObjectSystemObject, kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal)) {
        auto iterator = mac_device_global::all_devices_map().find(*data->data());
        if (iterator != mac_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return std::nullopt;
}

audio::io_device_ptr mac_device::renewable_default_output_device() {
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
            auto observer1 = device
                                 ->observe_io_device([handler](auto const &method) {
                                     if (method == audio::io_device::method::updated) {
                                         handler(renewable_device::method::notify);
                                     }
                                 })
                                 .end();

            auto observer2 = mac_device::observe_system([handler](auto const &) {
                                 handler(renewable_device::method::renewal);
                             }).end();

            return std::vector<observing::cancellable_ptr>{std::move(observer1), std::move(observer2)};
        });
}

std::optional<mac_device_ptr> mac_device::device_for_id(AudioDeviceID const audio_device_id) {
    auto it = mac_device_global::all_devices_map().find(audio_device_id);
    if (it != mac_device_global::all_devices_map().end()) {
        return it->second;
    }
    return std::nullopt;
}

std::optional<size_t> mac_device::index_of_device(mac_device_ptr const &device) {
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

bool mac_device::is_available_device(mac_device const &device) {
    auto it = mac_device_global::all_devices_map().find(device.audio_device_id());
    return it != mac_device_global::all_devices_map().end();
}

#pragma mark - main

mac_device::mac_device(AudioDeviceID const device_id)
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

    this->_notifier
        ->observe([this](auto const &method) { this->_io_device_notifier->notify(io_device::method::updated); })
        .end()
        ->add_to(this->_pool);

    audio::_system_notifier
        ->observe([this](auto const &) {
            if (!is_available_device(*this)) {
                this->_io_device_notifier->notify(io_device::method::lost);
            }
        })
        .end()
        ->add_to(this->_pool);
}

void mac_device::_prepare(mac_device_ptr const &mac_device) {
    this->_weak_mac_device = mac_device;
}

AudioDeviceID mac_device::audio_device_id() const {
    return this->_audio_device_id;
}

std::string mac_device::name() const {
    return to_string(_property_string(this->audio_device_id(), kAudioObjectPropertyName));
}

std::string mac_device::manufacture() const {
    return to_string(_property_string(this->audio_device_id(), kAudioObjectPropertyManufacturer));
}

std::vector<mac_device::stream_ptr> mac_device::input_streams() const {
    std::vector<stream_ptr> streams;
    for (auto &pair : this->_input_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

std::vector<mac_device::stream_ptr> mac_device::output_streams() const {
    std::vector<stream_ptr> streams;
    for (auto &pair : this->_output_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

double mac_device::nominal_sample_rate() const {
    if (auto const data = _property_data<double>(audio_device_id(), kAudioDevicePropertyNominalSampleRate,
                                                 kAudioObjectPropertyScopeGlobal)) {
        return *data->data();
    }
    return 0;
}

std::optional<audio::format> mac_device::input_format() const {
    return this->_input_format;
}

std::optional<audio::format> mac_device::output_format() const {
    return this->_output_format;
}

std::optional<audio::interruptor_ptr> const &mac_device::interruptor() const {
    static std::optional<interruptor_ptr> const _nullopt = std::nullopt;
    return _nullopt;
}

audio::io_core_ptr mac_device::make_io_core() const {
    return mac_io_core::make_shared(this->_weak_mac_device.lock());
}

observing::endable mac_device::observe(observing::caller<change_info>::handler_f &&handler) {
    return this->_notifier->observe(std::move(handler));
}

observing::endable mac_device::observe_system(observing::caller<change_info>::handler_f &&handler) {
    return audio::_system_notifier->observe(std::move(handler));
}

observing::endable mac_device::observe_io_device(observing::caller<io_device::method>::handler_f &&handler) {
    return this->_io_device_notifier->observe(std::move(handler));
}

mac_device::listener_f mac_device::_listener() {
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

void mac_device::_udpate_streams(AudioObjectPropertyScope const scope) {
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
                    mac_device::stream::make_shared({.stream_id = stream_id, .device_id = _audio_device_id})));
            }
        }
    }
}

void mac_device::_update_format(AudioObjectPropertyScope const scope) {
    stream_ptr stream = nullptr;

    if (scope == kAudioObjectPropertyScopeInput) {
        auto iterator = this->_input_streams_map.begin();
        if (iterator != this->_input_streams_map.end()) {
            stream = iterator->second;
            this->_input_format = std::nullopt;
        }
    } else if (scope == kAudioObjectPropertyScopeOutput) {
        auto iterator = this->_output_streams_map.begin();
        if (iterator != this->_output_streams_map.end()) {
            stream = iterator->second;
            this->_output_format = std::nullopt;
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
            this->_input_format = std::move(format);
        } else if (scope == kAudioObjectPropertyScopeOutput) {
            this->_output_format = std::move(format);
        }
    }
}

bool mac_device::operator==(mac_device const &rhs) const {
    return this->audio_device_id() == rhs.audio_device_id();
}

bool mac_device::operator!=(mac_device const &rhs) const {
    return !(*this == rhs);
}

#endif
