//
//  yas_audio_device.cpp
//

#include "yas_audio_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <mutex>

using namespace yas;

namespace yas::audio {

static chaining::notifier<audio::device::chaining_system_pair_t> _system_notifier;

#pragma mark - utility

template <typename T>
static std::unique_ptr<std::vector<T>> _property_data(AudioObjectID const object_id,
                                                      AudioObjectPropertySelector const selector,
                                                      AudioObjectPropertyScope const scope) {
    AudioObjectPropertyAddress const address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    UInt32 byte_size = 0;
    raise_if_raw_audio_error(AudioObjectGetPropertyDataSize(object_id, &address, 0, nullptr, &byte_size));
    uint32_t vector_size = byte_size / sizeof(T);

    if (vector_size > 0) {
        auto data = std::make_unique<std::vector<T>>(vector_size);
        byte_size = vector_size * sizeof(T);
        raise_if_raw_audio_error(AudioObjectGetPropertyData(object_id, &address, 0, nullptr, &byte_size, data->data()));
        return data;
    }

    return nullptr;
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
                          AudioObjectPropertyScope const scope, audio::device::listener_f const handler) {
    AudioObjectPropertyAddress const address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    raise_if_raw_audio_error(AudioObjectAddPropertyListenerBlock(
        object_id, &address, dispatch_get_main_queue(),
        ^(uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
            handler(address_count, addresses);
        }));
}

#pragma mark - device_global

struct device_global {
    struct audio_device_for_global : public device {
        audio_device_for_global(AudioDeviceID const device_id) : device(device_id) {
        }
    };

    static std::unordered_map<AudioDeviceID, std::shared_ptr<device>> &all_devices_map() {
        _initialize();
        return device_global::instance()._all_devices;
    }

    static audio::device::listener_f system_listener() {
        return [](uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
            update_all_devices();

            std::vector<device::property_info> property_infos;
            for (uint32_t i = 0; i < address_count; i++) {
                property_infos.push_back(device::property_info{.property = device::property::system,
                                                               .object_id = kAudioObjectSystemObject,
                                                               .address = addresses[i]});
            }
            device::change_info change_info{.property_infos = std::move(property_infos)};
            audio::_system_notifier.notify(std::make_pair(device::system_method::hardware_did_change, change_info));
            audio::_system_notifier.notify(std::make_pair(device::system_method::configuration_change, change_info));
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
                    map.insert(std::make_pair(device_id, std::make_shared<audio_device_for_global>(device_id)));
                }
            }
        }
    }

   private:
    std::unordered_map<AudioDeviceID, std::shared_ptr<device>> _all_devices;
    audio::device::listener_f _system_listener = nullptr;

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

    static device_global &instance() {
        static device_global _instance;
        return _instance;
    }

    device_global() = default;

    device_global(device_global const &) = delete;
    device_global(device_global &&) = delete;
    device_global &operator=(device_global const &) = delete;
    device_global &operator=(device_global &&) = delete;
};
}  // namespace yas::audio

#pragma mark - property_info

bool audio::device::property_info::operator<(device::property_info const &info) const {
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

std::vector<std::shared_ptr<audio::device>> audio::device::all_devices() {
    std::vector<std::shared_ptr<device>> devices;
    for (auto &pair : device_global::all_devices_map()) {
        devices.push_back(pair.second);
    }
    return devices;
}

std::vector<std::shared_ptr<audio::device>> audio::device::output_devices() {
    std::vector<std::shared_ptr<device>> devices;
    for (auto &pair : device_global::all_devices_map()) {
        if (pair.second->output_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::vector<std::shared_ptr<audio::device>> audio::device::input_devices() {
    std::vector<std::shared_ptr<device>> devices;
    for (auto &pair : device_global::all_devices_map()) {
        if (pair.second->input_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::shared_ptr<audio::device> audio::device::default_system_output_device() {
    if (auto const data =
            _property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice,
                                          kAudioObjectPropertyScopeGlobal)) {
        auto iterator = device_global::all_devices_map().find(*data->data());
        if (iterator != device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return nullptr;
}

std::shared_ptr<audio::device> audio::device::default_output_device() {
    if (auto const data = _property_data<AudioDeviceID>(
            kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)) {
        auto iterator = device_global::all_devices_map().find(*data->data());
        if (iterator != device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return nullptr;
}

std::shared_ptr<audio::device> audio::device::default_input_device() {
    if (auto const data = _property_data<AudioDeviceID>(
            kAudioObjectSystemObject, kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal)) {
        auto iterator = device_global::all_devices_map().find(*data->data());
        if (iterator != device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return nullptr;
}

std::shared_ptr<audio::device> audio::device::device_for_id(AudioDeviceID const audio_device_id) {
    auto it = device_global::all_devices_map().find(audio_device_id);
    if (it != device_global::all_devices_map().end()) {
        return it->second;
    }
    return nullptr;
}

std::optional<size_t> audio::device::index_of_device(device const &device) {
    auto all_devices = device::all_devices();
    auto it = std::find_if(all_devices.begin(), all_devices.end(), [&device](auto const &value){ return value->audio_device_id() == device.audio_device_id(); });
    if (it != all_devices.end()) {
        return std::make_optional<size_t>(it - all_devices.begin());
    } else {
        return std::nullopt;
    }
}

bool audio::device::is_available_device(device const &device) {
    auto it = device_global::all_devices_map().find(device.audio_device_id());
    return it != device_global::all_devices_map().end();
}

#pragma mark - main

audio::device::device(AudioDeviceID const device_id) : _input_format(std::nullopt), _output_format(std::nullopt), _audio_device_id(device_id) {
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

AudioDeviceID audio::device::audio_device_id() const {
    return this->_audio_device_id;
}

CFStringRef audio::device::name() const {
    return _property_string(audio_device_id(), kAudioObjectPropertyName);
}

CFStringRef audio::device::manufacture() const {
    return _property_string(audio_device_id(), kAudioObjectPropertyManufacturer);
}

std::vector<audio::device::stream> audio::device::input_streams() const {
    std::vector<stream> streams;
    for (auto &pair : this->input_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

std::vector<audio::device::stream> audio::device::output_streams() const {
    std::vector<stream> streams;
    for (auto &pair : this->output_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

double audio::device::nominal_sample_rate() const {
    if (auto const data = _property_data<double>(audio_device_id(), kAudioDevicePropertyNominalSampleRate,
                                                 kAudioObjectPropertyScopeGlobal)) {
        return *data->data();
    }
    return 0;
}

void audio::device::set_input_format(std::optional<audio::format> const &format) {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    this->_input_format = format;
}

std::optional<audio::format> audio::device::input_format() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return this->_input_format;
}

void audio::device::set_output_format(std::optional<audio::format> const &format) {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    this->_output_format = format;
}

std::optional<audio::format> audio::device::output_format() const {
    std::lock_guard<std::recursive_mutex> lock(_mutex);
    return this->_output_format;
}

uint32_t audio::device::input_channel_count() const {
    if (auto input_format = this->input_format()) {
        return input_format->channel_count();
    }
    return 0;
}

uint32_t audio::device::output_channel_count() const {
    if (auto output_format = this->output_format()) {
        return output_format->channel_count();
    }
    return 0;
}

chaining::chain_unsync_t<audio::device::chaining_pair_t> audio::device::chain() const {
    return this->_notifier.chain();
}

chaining::chain_relayed_unsync_t<audio::device::change_info, audio::device::chaining_pair_t> audio::device::chain(
    method const method) const {
    return this->_notifier.chain()
        .guard([method](audio::device::chaining_pair_t const &pair) { return pair.first == method; })
        .to([](audio::device::chaining_pair_t const &pair) { return pair.second; });
}

chaining::chain_unsync_t<audio::device::chaining_system_pair_t> audio::device::system_chain() {
    return audio::_system_notifier.chain();
}

chaining::chain_relayed_unsync_t<audio::device::change_info, audio::device::chaining_system_pair_t>
audio::device::system_chain(system_method const method) {
    return audio::_system_notifier.chain()
        .guard([method](chaining_system_pair_t const &pair) { return pair.first == method; })
        .to([](chaining_system_pair_t const &pair) { return pair.second; });
}

audio::device::listener_f audio::device::_listener() {
    AudioDeviceID const device_id = this->_audio_device_id;
    
    return [device_id](uint32_t const address_count, const AudioObjectPropertyAddress *const addresses) {
        auto device = device::device_for_id(device_id);
        if (device) {
            AudioObjectID const object_id = device->audio_device_id();
            
            std::vector<device::property_info> property_infos;
            for (uint32_t i = 0; i < address_count; ++i) {
                if (addresses[i].mSelector == kAudioDevicePropertyStreams) {
                    property_infos.emplace_back(property_info{
                        .property = property::stream, .object_id = object_id, .address = addresses[i]});
                } else if (addresses[i].mSelector == kAudioDevicePropertyStreamConfiguration) {
                    property_infos.emplace_back(property_info{
                        .property = property::format, .object_id = object_id, .address = addresses[i]});
                } else if (addresses[i].mSelector == kAudioDevicePropertyNominalSampleRate) {
                    if (addresses[i].mScope == kAudioObjectPropertyScopeGlobal) {
                        AudioObjectPropertyAddress address = addresses[i];
                        address.mScope = kAudioObjectPropertyScopeOutput;
                        property_infos.emplace_back(property_info{
                            .property = property::format, .object_id = object_id, .address = address});
                        address.mScope = kAudioObjectPropertyScopeInput;
                        property_infos.emplace_back(property_info{
                            .property = property::format, .object_id = object_id, .address = address});
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
            
            device::change_info change_info{std::move(property_infos)};
            device->_notifier.notify(std::make_pair(method::device_did_change, change_info));
            audio::_system_notifier.notify(
                                           std::make_pair(device::system_method::configuration_change, change_info));
        }
    };
}

void audio::device::_udpate_streams(AudioObjectPropertyScope const scope) {
    auto prev_streams =
    std::move((scope == kAudioObjectPropertyScopeInput) ? this->input_streams_map : this->output_streams_map);
    auto data = _property_data<AudioStreamID>(this->_audio_device_id, kAudioDevicePropertyStreams, scope);
    auto &new_streams = (scope == kAudioObjectPropertyScopeInput) ? this->input_streams_map : this->output_streams_map;
    if (data) {
        for (auto &stream_id : *data) {
            if (prev_streams.count(stream_id) > 0) {
                new_streams.insert(std::make_pair(stream_id, prev_streams.at(stream_id)));
            } else {
                new_streams.insert(
                                   std::make_pair(stream_id, stream({.stream_id = stream_id, .device_id = _audio_device_id})));
            }
        }
    }
}

void audio::device::_update_format(AudioObjectPropertyScope const scope) {
    std::optional<stream> stream = std::nullopt;
    
    if (scope == kAudioObjectPropertyScopeInput) {
        auto iterator = this->input_streams_map.begin();
        if (iterator != this->input_streams_map.end()) {
            stream = iterator->second;
            this->set_input_format(std::nullopt);
        }
    } else if (scope == kAudioObjectPropertyScopeOutput) {
        auto iterator = this->output_streams_map.begin();
        if (iterator != this->output_streams_map.end()) {
            stream = iterator->second;
            this->set_output_format(std::nullopt);
        }
    }
    
    if (!stream) {
        return;
    }
    
    auto stream_format = stream->virtual_format();
    
    auto data =
    _property_data<AudioBufferList>(this->_audio_device_id, kAudioDevicePropertyStreamConfiguration, scope);
    if (data) {
        uint32_t channel_count = 0;
        for (auto &abl : *data) {
            for (uint32_t i = 0; i < abl.mNumberBuffers; i++) {
                channel_count += abl.mBuffers[i].mNumberChannels;
            }
            
            audio::format format({.sample_rate = stream_format.sample_rate(),
                .channel_count = channel_count,
                .pcm_format = stream_format.pcm_format(),
                .interleaved = false});
            
            if (scope == kAudioObjectPropertyScopeInput) {
                this->set_input_format(format);
            } else if (scope == kAudioObjectPropertyScopeOutput) {
                this->set_output_format(format);
            }
        }
    }
}

chaining::notifier<audio::device::chaining_system_pair_t> &audio::device::system_notifier() {
    return audio::_system_notifier;
}

bool audio::device::operator==(device const &rhs) const {
    return this->audio_device_id() == rhs.audio_device_id();
}

bool audio::device::operator!=(device const &rhs) const {
    return !(*this == rhs);
}

std::string yas::to_string(audio::device::method const &method) {
    switch (method) {
        case audio::device::method::device_did_change:
            return "device_did_change";
    }
}

std::string yas::to_string(audio::device::system_method const &method) {
    switch (method) {
        case audio::device::system_method::hardware_did_change:
            return "hardware_did_change";
        case audio::device::system_method::configuration_change:
            return "configuration_change";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::device::method const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::device::system_method const &value) {
    os << to_string(value);
    return os;
}

#endif
