//
//  yas_audio_device.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_types.h"
#include "yas_observing.h"
#include "yas_audio_format.h"
#include <AudioToolbox/AudioToolbox.h>
#include <vector>
#include <unordered_map>
#include <set>
#include <memory>
#include <string>
#include <experimental/optional>

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

        constexpr static auto hardware_did_change_key = "yas.audio.device.hardware_did_change";
        constexpr static auto device_did_change_key = "yas.audio.device.device_did_change";
        constexpr static auto configuration_change_key = "yas.audio.device.configuration_change";

        struct property_info {
            const AudioObjectID object_id;
            const device::property property;
            const AudioObjectPropertyAddress address;

            property_info(const device::property property, const AudioObjectID object_id,
                          const AudioObjectPropertyAddress &address);

            bool operator<(const property_info &info) const;
        };

        struct change_info {
            const std::vector<property_info> property_infos;

            change_info(std::vector<property_info> &&infos);
        };

        static std::vector<device> all_devices();
        static std::vector<device> output_devices();
        static std::vector<device> input_devices();
        static device default_system_output_device();
        static device default_output_device();
        static device default_input_device();
        static device device_for_id(const AudioDeviceID);
        static std::experimental::optional<size_t> index_of_device(const device &);
        static bool is_available_device(const device &);

        device(std::nullptr_t);

        ~device();

        device(const device &) = default;
        device(device &&) = default;
        device &operator=(const device &) = default;
        device &operator=(device &&) = default;

        bool operator==(const device &) const;
        bool operator!=(const device &) const;

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
        explicit device(const AudioDeviceID device_id);

       private:
        class impl;
    };
}
}

#include "yas_audio_device_stream.h"

#endif
