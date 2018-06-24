//
//  yas_audio_device.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <AudioToolbox/AudioToolbox.h>
#include <experimental/optional>
#include <string>
#include <vector>
#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_flow.h"

namespace yas::audio {
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

    enum class method { device_did_change };
    enum class system_method { hardware_did_change, configuration_change };

    struct property_info {
        AudioObjectID const object_id;
        device::property const property;
        AudioObjectPropertyAddress const address;

        bool operator<(property_info const &info) const;
    };

    struct change_info {
        std::vector<property_info> const property_infos;
    };

    using flow_pair_t = std::pair<method, change_info>;
    using flow_system_pair_t = std::pair<system_method, change_info>;

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

    [[nodiscard]] flow::node_t<flow_pair_t, false> begin_flow() const;
    [[nodiscard]] flow::node<change_info, flow_pair_t, flow_pair_t, false> begin_flow(method const) const;
    [[nodiscard]] static flow::node_t<flow_system_pair_t, false> begin_system_flow();
    [[nodiscard]] static flow::node<change_info, flow_system_pair_t, flow_system_pair_t, false> begin_system_flow(
        system_method const);

#if YAS_TEST
    static flow::notifier<flow_system_pair_t> &system_notifier();
#endif

   protected:
    explicit device(AudioDeviceID const device_id);
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::device::method const &);
std::string to_string(audio::device::system_method const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::device::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::device::system_method const &);

#include "yas_audio_device_stream.h"

#endif
