//
//  yas_audio_device.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <AudioToolbox/AudioToolbox.h>
#include <chaining/yas_chaining_umbrella.h>
#include <optional>
#include <ostream>
#include <string>
#include <vector>
#include "yas_audio_format.h"
#include "yas_audio_types.h"

namespace yas::audio {
class device_global;

struct device {
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

    using chaining_pair_t = std::pair<method, change_info>;
    using chaining_system_pair_t = std::pair<system_method, change_info>;

    static std::vector<std::shared_ptr<device>> all_devices();
    static std::vector<std::shared_ptr<device>> output_devices();
    static std::vector<std::shared_ptr<device>> input_devices();
    static std::shared_ptr<device> default_system_output_device();
    static std::shared_ptr<device> default_output_device();
    static std::shared_ptr<device> default_input_device();
    static std::shared_ptr<device> device_for_id(AudioDeviceID const);
    static std::optional<size_t> index_of_device(device const &);
    static bool is_available_device(device const &);

    AudioDeviceID audio_device_id() const;
    CFStringRef name() const;
    CFStringRef manufacture() const;
    std::vector<std::shared_ptr<stream>> input_streams() const;
    std::vector<std::shared_ptr<stream>> output_streams() const;
    double nominal_sample_rate() const;

    std::optional<audio::format> input_format() const;
    std::optional<audio::format> output_format() const;
    uint32_t input_channel_count() const;
    uint32_t output_channel_count() const;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<change_info, chaining_pair_t> chain(method const) const;
    [[nodiscard]] static chaining::chain_unsync_t<chaining_system_pair_t> system_chain();
    [[nodiscard]] static chaining::chain_relayed_unsync_t<change_info, chaining_system_pair_t> system_chain(
        system_method const);

    // for Test
    static chaining::notifier<chaining_system_pair_t> &system_notifier();

    using listener_f =
        std::function<void(uint32_t const in_number_addresses, const AudioObjectPropertyAddress *const in_addresses)>;

    bool operator==(device const &) const;
    bool operator!=(device const &) const;

    device(device &&) = default;
    device &operator=(device &&) = default;

   protected:
    explicit device(AudioDeviceID const device_id);

   private:
    AudioDeviceID const _audio_device_id;
    std::unordered_map<AudioStreamID, std::shared_ptr<stream>> _input_streams_map;
    std::unordered_map<AudioStreamID, std::shared_ptr<stream>> _output_streams_map;
    chaining::notifier<audio::device::chaining_pair_t> _notifier;
    std::optional<audio::format> _input_format = std::nullopt;
    std::optional<audio::format> _output_format = std::nullopt;
    mutable std::recursive_mutex _mutex;

    void _set_input_format(std::optional<audio::format> const &format);
    void _set_output_format(std::optional<audio::format> const &format);

    listener_f _listener();
    void _udpate_streams(AudioObjectPropertyScope const scope);
    void _update_format(AudioObjectPropertyScope const scope);

    device(device const &) = delete;
    device &operator=(device const &) = delete;
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
