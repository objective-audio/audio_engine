//
//  yas_audio_device.h
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
#include "yas_audio_types.h"
#include "yas_base.h"

namespace yas {
template <typename T, typename K>
class subject;
template <typename T, typename K>
class observer;

namespace audio {
    class device_global;
    class format;

    class device : public base {
        class impl;

       public:
        class stream;

        enum class property : uint32_t {
            system,
            stream,
            format,
        };

        enum class method { hardware_did_change, device_did_change, configuration_change };

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
        };

        using subject_t = subject<change_info, method>;
        using observer_t = observer<change_info, method>;

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

        AudioDeviceID audio_device_id() const;
        CFStringRef name() const;
        CFStringRef manufacture() const;
        std::vector<stream> input_streams() const;
        std::vector<stream> output_streams() const;
        double nominal_sample_rate() const;

        audio::format input_format() const;
        audio::format output_format() const;
        uint32_t input_channel_count() const;
        uint32_t output_channel_count() const;

        static subject_t &system_subject();
        subject_t &subject() const;

       protected:
        explicit device(AudioDeviceID const device_id);
    };
}
}

#include "yas_audio_device_stream.h"

#endif
