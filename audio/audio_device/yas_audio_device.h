//
//  yas_audio_device.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <AudioToolbox/AudioToolbox.h>
#include <experimental/optional>
#include <memory>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>
#include "yas_audio_format.h"
#include "yas_audio_types.h"
#include "yas_observing.h"

namespace yas {
namespace audio {
    class device_global;

    class device : public base {
        using super_class = base;

       public:
        class stream;

        enum class property : UInt32 {
            system,
            stream,
            format,
        };

        static auto constexpr hardware_did_change_key = "yas.audio.device.hardware_did_change";
        static auto constexpr device_did_change_key = "yas.audio.device.device_did_change";
        static auto constexpr configuration_change_key = "yas.audio.device.configuration_change";

        struct property_info {
            AudioObjectID const object_id;
            device::property const property;
            AudioObjectPropertyAddress const address;

            property_info(device::property const property, AudioObjectID const object_id,
                          AudioObjectPropertyAddress const &address);

            bool operator<(property_info const &info) const;
        };

        struct change_info {
            std::vector<property_info> const property_infos;

            change_info(std::vector<property_info> &&infos);
        };

        static std::vector<device> all_devices();
        static std::vector<device> output_devices();
        static std::vector<device> input_devices();
        static device default_system_output_device();
        static device default_output_device();
        static device default_input_device();
        static device device_for_id(AudioDeviceID const);
        static std::experimental::optional<size_t> index_of_device(device const &);
        static bool is_available_device(device const &);

        device(std::nullptr_t);

        ~device();

        device(device const &) = default;
        device(device &&) = default;
        device &operator=(device const &) = default;
        device &operator=(device &&) = default;

        bool operator==(device const &) const;
        bool operator!=(device const &) const;

        explicit operator bool() const;

        AudioDeviceID audio_device_id() const;
        CFStringRef name() const;
        CFStringRef manufacture() const;
        std::vector<stream> input_streams() const;
        std::vector<stream> output_streams() const;
        Float64 nominal_sample_rate() const;

        audio::format input_format() const;
        audio::format output_format() const;
        UInt32 input_channel_count() const;
        UInt32 output_channel_count() const;

        static subject<change_info> &system_subject();
        subject<change_info> &subject() const;

       protected:
        explicit device(AudioDeviceID const device_id);

       private:
        class impl;
    };
}
}

#include "yas_audio_device_stream.h"

#endif
