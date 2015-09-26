//
//  yas_audio_device.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_format.h"
#include "yas_audio_device_stream.h"
#include "yas_cf_utils.h"
#include <mutex>
#include <memory>

using namespace yas;

using listener_f =
    std::function<void(const UInt32 in_number_addresses, const AudioObjectPropertyAddress *in_addresses)>;

#pragma mark - utility

template <typename T>
static std::unique_ptr<std::vector<T>> property_data(const AudioObjectID object_id,
                                                     const AudioObjectPropertySelector selector,
                                                     const AudioObjectPropertyScope scope)
{
    const AudioObjectPropertyAddress address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    UInt32 byte_size = 0;
    yas_raise_if_au_error(AudioObjectGetPropertyDataSize(object_id, &address, 0, nullptr, &byte_size));
    UInt32 vector_size = byte_size / sizeof(T);

    if (vector_size > 0) {
        auto data = std::make_unique<std::vector<T>>(vector_size);
        byte_size = vector_size * sizeof(T);
        yas_raise_if_au_error(AudioObjectGetPropertyData(object_id, &address, 0, nullptr, &byte_size, data->data()));
        return data;
    }

    return nullptr;
}

static CFStringRef property_string(const AudioObjectID object_id, const AudioObjectPropertySelector selector)
{
    const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    CFStringRef cfString = nullptr;
    UInt32 size = sizeof(CFStringRef);
    yas_raise_if_au_error(AudioObjectGetPropertyData(object_id, &address, 0, nullptr, &size, &cfString));
    if (cfString) {
        return (CFStringRef)CFAutorelease(cfString);
    }

    return nullptr;
}

static void add_listener(const AudioObjectID object_id, const AudioObjectPropertySelector selector,
                         const AudioObjectPropertyScope scope, const listener_f function)
{
    const AudioObjectPropertyAddress address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    yas_raise_if_au_error(
        AudioObjectAddPropertyListenerBlock(object_id, &address, dispatch_get_main_queue(),
                                            ^(UInt32 address_count, const AudioObjectPropertyAddress *addresses) {
                                                function(address_count, addresses);
                                            }));
}

#pragma mark - audio_device_global

namespace yas
{
    class audio_device_global
    {
       public:
        static void initialize()
        {
            static bool once = false;
            if (!once) {
                once = true;

                update_all_devices();
                auto listener = system_listener();
                add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
                             listener);
                add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice,
                             kAudioObjectPropertyScopeGlobal, listener);
                add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice,
                             kAudioObjectPropertyScopeGlobal, listener);
                add_listener(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultInputDevice,
                             kAudioObjectPropertyScopeGlobal, listener);
            }
        }

        static std::map<AudioDeviceID, audio_device_sptr> &all_devices_map()
        {
            initialize();
            return audio_device_global::instance()._all_devices;
        }

        static listener_f system_listener()
        {
            return [](UInt32 address_count, const AudioObjectPropertyAddress *addresses) {
                update_all_devices();

                auto infos = std::make_shared<std::vector<audio_device::property_info>>();
                for (UInt32 i = 0; i < address_count; i++) {
                    infos->push_back(audio_device::property_info(audio_device::property::system,
                                                                 kAudioObjectSystemObject, addresses[i]));
                }
                auto &subject = audio_device::system_subject();
                subject.notify(audio_device_method::hardware_did_change, infos);
                subject.notify(audio_device_method::configuration_change, infos);
            };
        }

        static void update_all_devices()
        {
            auto prev_devices = std::move(all_devices_map());
            auto data = property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDevices,
                                                     kAudioObjectPropertyScopeGlobal);
            if (data) {
                auto &map = all_devices_map();
                for (const auto &device_id : *data) {
                    if (prev_devices.count(device_id) > 0) {
                        map[device_id] = prev_devices.at(device_id);
                    } else {
                        map[device_id] = audio_device_sptr(new audio_device(device_id));
                    }
                }
            }
        }

       private:
        std::map<AudioDeviceID, audio_device_sptr> _all_devices;
        listener_f _system_listener = nullptr;

        static audio_device_global &instance()
        {
            static audio_device_global _instance;
            return _instance;
        }

        audio_device_global()
        {
        }

        audio_device_global(const audio_device_global &) = delete;
        audio_device_global(audio_device_global &&) = delete;
        audio_device_global &operator=(const audio_device_global &) = delete;
        audio_device_global &operator=(audio_device_global &&) = delete;
    };
}

#pragma mark - property_info

audio_device::property_info::property_info(const audio_device::property property, const AudioObjectID object_id,
                                           const AudioObjectPropertyAddress &address)
    : property(property), object_id(object_id), address(address)
{
}

bool audio_device::property_info::operator<(const audio_device::property_info &info) const
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

class audio_device::impl
{
   public:
    const AudioDeviceID audio_device_id;
    std::map<AudioStreamID, audio_device_stream_sptr> input_streams_map;
    std::map<AudioStreamID, audio_device_stream_sptr> output_streams_map;
    subject property_subject;

    impl(AudioDeviceID device_id)
        : _input_format(nullptr),
          _output_format(nullptr),
          _mutex(),
          audio_device_id(device_id),
          input_streams_map(),
          output_streams_map(),
          property_subject()
    {
    }

    ~impl()
    {
    }

    void set_input_format(const audio_format_sptr &format)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _input_format = format;
    }

    audio_format_sptr input_format() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _input_format;
    }

    void set_output_format(const audio_format_sptr &format)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _output_format = format;
    }

    audio_format_sptr output_format() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _output_format;
    }

    listener_f listener()
    {
        const AudioDeviceID device_id = audio_device_id;

        return [device_id](const UInt32 address_count, const AudioObjectPropertyAddress *addresses) {
            auto device = audio_device::device_for_id(device_id);
            if (device) {
                const AudioObjectID object_id = device->audio_device_id();
                property_infos_sptr infos = std::make_shared<std::vector<property_info>>();
                for (UInt32 i = 0; i < address_count; ++i) {
                    if (addresses[i].mSelector == kAudioDevicePropertyStreams) {
                        infos->push_back(property_info(property::stream, object_id, addresses[i]));
                    } else if (addresses[i].mSelector == kAudioDevicePropertyStreamConfiguration) {
                        infos->push_back(property_info(property::format, object_id, addresses[i]));
                    } else if (addresses[i].mSelector == kAudioDevicePropertyNominalSampleRate) {
                        if (addresses[i].mScope == kAudioObjectPropertyScopeGlobal) {
                            AudioObjectPropertyAddress address = addresses[i];
                            address.mScope = kAudioObjectPropertyScopeOutput;
                            infos->push_back(property_info(property::format, object_id, address));
                            address.mScope = kAudioObjectPropertyScopeInput;
                            infos->push_back(property_info(property::format, object_id, address));
                        }
                    }
                }

                for (auto &info : *infos) {
                    switch (info.property) {
                        case property::stream:
                            device->_impl->udpate_streams(info.address.mScope);
                            break;
                        case property::format:
                            device->_impl->update_format(info.address.mScope);
                            break;
                        default:
                            break;
                    }
                }

                device->property_subject().notify(audio_device_method::device_did_change, infos);
                audio_device::system_subject().notify(audio_device_method::configuration_change, infos);
            }
        };
    }

    void udpate_streams(const AudioObjectPropertyScope scope)
    {
        auto prev_streams =
            std::move((scope == kAudioObjectPropertyScopeInput) ? input_streams_map : output_streams_map);
        auto data = property_data<AudioStreamID>(audio_device_id, kAudioDevicePropertyStreams, scope);
        auto &new_streams = (scope == kAudioObjectPropertyScopeInput) ? input_streams_map : output_streams_map;
        if (data) {
            for (auto &stream_id : *data) {
                if (prev_streams.count(stream_id) > 0) {
                    new_streams[stream_id] = prev_streams.at(stream_id);
                } else {
                    new_streams[stream_id] = audio_device_stream::create(stream_id, audio_device_id);
                }
            }
        }
    }

    void update_format(const AudioObjectPropertyScope scope)
    {
        audio_device_stream_sptr stream = nullptr;

        if (scope == kAudioObjectPropertyScopeInput) {
            auto iterator = input_streams_map.begin();
            if (iterator != input_streams_map.end()) {
                stream = iterator->second;
                set_input_format(nullptr);
            }
        } else if (scope == kAudioObjectPropertyScopeOutput) {
            auto iterator = output_streams_map.begin();
            if (iterator != output_streams_map.end()) {
                stream = iterator->second;
                set_output_format(nullptr);
            }
        }

        if (!stream) {
            return;
        }

        auto stream_format = stream->virtual_format();

        auto data = property_data<AudioBufferList>(audio_device_id, kAudioDevicePropertyStreamConfiguration, scope);
        if (data) {
            UInt32 channel_count = 0;
            for (auto &abl : *data) {
                for (UInt32 i = 0; i < abl.mNumberBuffers; i++) {
                    channel_count += abl.mBuffers[i].mNumberChannels;
                }

                auto format = std::make_shared<audio_format>(stream_format.sample_rate(), channel_count,
                                                             stream_format.pcm_format(), false);

                if (scope == kAudioObjectPropertyScopeInput) {
                    set_input_format(format);
                } else if (scope == kAudioObjectPropertyScopeOutput) {
                    set_output_format(format);
                }
            }
        }
    }

   private:
    audio_format_sptr _input_format;
    audio_format_sptr _output_format;
    mutable std::recursive_mutex _mutex;
};

#pragma mark - global

std::vector<audio_device_sptr> audio_device::all_devices()
{
    std::vector<audio_device_sptr> devices;
    for (auto &pair : audio_device_global::all_devices_map()) {
        devices.push_back(pair.second);
    }
    return devices;
}

std::vector<audio_device_sptr> audio_device::output_devices()
{
    std::vector<audio_device_sptr> devices;
    for (auto &pair : audio_device_global::all_devices_map()) {
        if (pair.second->output_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

std::vector<audio_device_sptr> audio_device::input_devices()
{
    std::vector<audio_device_sptr> devices;
    for (auto &pair : audio_device_global::all_devices_map()) {
        if (pair.second->input_streams().size() > 0) {
            devices.push_back(pair.second);
        }
    }
    return devices;
}

const audio_device_sptr audio_device::default_system_output_device()
{
    auto data = property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultSystemOutputDevice,
                                             kAudioObjectPropertyScopeGlobal);
    if (data) {
        auto iterator = audio_device_global::all_devices_map().find(*data->data());
        if (iterator != audio_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return nullptr;
}

const audio_device_sptr audio_device::default_output_device()
{
    auto data = property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice,
                                             kAudioObjectPropertyScopeGlobal);
    if (data) {
        auto iterator = audio_device_global::all_devices_map().find(*data->data());
        if (iterator != audio_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return nullptr;
}

const audio_device_sptr audio_device::default_input_device()
{
    auto data = property_data<AudioDeviceID>(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultInputDevice,
                                             kAudioObjectPropertyScopeGlobal);
    if (data) {
        auto iterator = audio_device_global::all_devices_map().find(*data->data());
        if (iterator != audio_device_global::all_devices_map().end()) {
            return iterator->second;
        }
    }
    return nullptr;
}

const audio_device_sptr audio_device::device_for_id(const AudioDeviceID audio_device_id)
{
    auto iterator = audio_device_global::all_devices_map().find(audio_device_id);
    if (iterator != audio_device_global::all_devices_map().end()) {
        return audio_device_global::all_devices_map().at(audio_device_id);
    }
    return nullptr;
}

const std::experimental::optional<size_t> audio_device::index_of_device(const audio_device_sptr &device)
{
    if (device) {
        auto all_devices = audio_device::all_devices();
        auto it = std::find(all_devices.begin(), all_devices.end(), device);
        if (it != all_devices.end()) {
            return std::experimental::make_optional<size_t>(it - all_devices.begin());
        }
    }
    return nullopt;
}

subject &audio_device::system_subject()
{
    static subject system_subject;
    return system_subject;
}

#pragma mark - main

audio_device::audio_device(const AudioDeviceID device_id)
{
    _impl = std::make_unique<impl>(device_id);

    _impl->udpate_streams(kAudioObjectPropertyScopeInput);
    _impl->udpate_streams(kAudioObjectPropertyScopeOutput);
    _impl->update_format(kAudioObjectPropertyScopeInput);
    _impl->update_format(kAudioObjectPropertyScopeOutput);

    auto listener = _impl->listener();
    add_listener(device_id, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal, listener);
    add_listener(device_id, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput, listener);
    add_listener(device_id, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput, listener);
    add_listener(device_id, kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeInput, listener);
    add_listener(device_id, kAudioDevicePropertyStreamConfiguration, kAudioObjectPropertyScopeOutput, listener);
}

audio_device::~audio_device() = default;

bool audio_device::operator==(const audio_device &other_device) const
{
    return audio_device_id() == other_device.audio_device_id();
}

bool audio_device::operator!=(const audio_device &other_device) const
{
    return audio_device_id() != other_device.audio_device_id();
}

AudioDeviceID audio_device::audio_device_id() const
{
    return _impl->audio_device_id;
}

CFStringRef audio_device::name() const
{
    return property_string(audio_device_id(), kAudioObjectPropertyName);
}

CFStringRef audio_device::manufacture() const
{
    return property_string(audio_device_id(), kAudioObjectPropertyManufacturer);
}

std::vector<audio_device_stream_sptr> audio_device::input_streams() const
{
    std::vector<audio_device_stream_sptr> streams;
    for (auto &pair : _impl->input_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

std::vector<audio_device_stream_sptr> audio_device::output_streams() const
{
    std::vector<audio_device_stream_sptr> streams;
    for (auto &pair : _impl->output_streams_map) {
        streams.push_back(pair.second);
    }
    return streams;
}

Float64 audio_device::nominal_sample_rate() const
{
    auto data = property_data<Float64>(audio_device_id(), kAudioDevicePropertyNominalSampleRate,
                                       kAudioObjectPropertyScopeGlobal);
    if (data) {
        return *data->data();
    }
    return 0;
}

audio_format_sptr audio_device::input_format() const
{
    return _impl->input_format();
}

audio_format_sptr audio_device::output_format() const
{
    return _impl->output_format();
}

UInt32 audio_device::input_channel_count() const
{
    if (const auto format = _impl->input_format()) {
        return format->channel_count();
    }
    return 0;
}

UInt32 audio_device::output_channel_count() const
{
    if (const auto format = _impl->output_format()) {
        return format->channel_count();
    }
    return 0;
}

subject &audio_device::property_subject() const
{
    return _impl->property_subject;
}

#endif
