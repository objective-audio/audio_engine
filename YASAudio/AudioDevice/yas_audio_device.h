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
#include "yas_audio_device_stream.h"
#include <AudioToolbox/AudioToolbox.h>
#include <vector>
#include <unordered_map>
#include <set>
#include <memory>
#include <string>
#include <experimental/optional>

namespace yas
{
    class audio_device_global;

    namespace audio_device_method
    {
        static const auto hardware_did_change = "yas.audio_device.hardware_did_change";
        static const auto device_did_change = "yas.audio_device.device_did_change";
        static const auto configuration_change = "yas.audio_device.configuration_change";
    }

    class audio_device
    {
       public:
        enum class property : UInt32 {
            system,
            stream,
            format,
        };

        class property_info
        {
           public:
            const AudioObjectID object_id;
            const audio_device::property property;
            const AudioObjectPropertyAddress address;

            property_info(const audio_device::property property, const AudioObjectID object_id,
                          const AudioObjectPropertyAddress &address);

            bool operator<(const property_info &info) const;
        };

        using property_infos_sptr = std::shared_ptr<std::vector<property_info>>;

        static std::vector<audio_device> all_devices();
        static std::vector<audio_device> output_devices();
        static std::vector<audio_device> input_devices();
        static audio_device default_system_output_device();
        static audio_device default_output_device();
        static audio_device default_input_device();
        static audio_device device_for_id(const AudioDeviceID);
        static std::experimental::optional<size_t> index_of_device(const audio_device &);

        audio_device(std::nullptr_t n = nullptr);

        ~audio_device() = default;

        audio_device(const audio_device &) = default;
        audio_device(audio_device &&) = default;
        audio_device &operator=(const audio_device &) = default;
        audio_device &operator=(audio_device &&) = default;

        bool operator==(const audio_device &) const;
        bool operator!=(const audio_device &) const;

        explicit operator bool() const;

        AudioDeviceID audio_device_id() const;
        CFStringRef name() const;
        CFStringRef manufacture() const;
        std::vector<audio_device_stream> input_streams() const;
        std::vector<audio_device_stream> output_streams() const;
        Float64 nominal_sample_rate() const;

        audio_format input_format() const;
        audio_format output_format() const;
        UInt32 input_channel_count() const;
        UInt32 output_channel_count() const;

        static subject &system_subject();
        subject &property_subject() const;

       protected:
        explicit audio_device(const AudioDeviceID device_id);

       private:
        class impl;
        std::shared_ptr<impl> _impl;
    };
}

#endif
