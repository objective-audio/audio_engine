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
#include <map>
#include <set>
#include <memory>
#include <string>
#include <experimental/optional>

namespace yas
{
    class audio_device_global;

    class audio_device
    {
       public:
        enum class method : UInt32 {
            hardware_did_change,
            device_did_change,
            configulation_change,
        };

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

        using system_subject_type = subject<method, std::vector<property_info>>;
        using property_subject_type = subject<method, std::vector<property_info>>;

        static std::vector<audio_device_ptr> all_devices();
        static std::vector<audio_device_ptr> output_devices();
        static std::vector<audio_device_ptr> input_devices();
        static const audio_device_ptr default_system_output_device();
        static const audio_device_ptr default_output_device();
        static const audio_device_ptr default_input_device();
        static const audio_device_ptr device_for_id(const AudioDeviceID);
        static const std::experimental::optional<size_t> index_of_device(const audio_device_ptr &);

        ~audio_device();

        bool operator==(const audio_device &) const;
        bool operator!=(const audio_device &) const;

        AudioDeviceID audio_device_id() const;
        std::string name() const;
        std::string manufacture() const;
        CFStringRef cf_name() const;
        CFStringRef cf_manufacture() const;
        std::vector<audio_device_stream_ptr> input_streams() const;
        std::vector<audio_device_stream_ptr> output_streams() const;
        Float64 nominal_sample_rate() const;

        audio_format_ptr input_format() const;
        audio_format_ptr output_format() const;
        uint32_t input_channel_count() const;
        uint32_t output_channel_count() const;

        static system_subject_type &system_subject();
        property_subject_type &property_subject() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        explicit audio_device(const AudioDeviceID device_id);

        audio_device(const audio_device &) = delete;
        audio_device(audio_device &&) = delete;
        audio_device &operator=(const audio_device &) = delete;
        audio_device &operator=(audio_device &&) = delete;

        friend audio_device_global;
    };

    using audio_device_observer = observer<audio_device::method, std::vector<audio_device::property_info>>;
    using audio_device_observer_ptr = audio_device_observer::shared_ptr;
}

#endif
