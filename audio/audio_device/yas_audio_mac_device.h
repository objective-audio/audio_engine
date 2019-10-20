//
//  yas_audio_mac_device.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_ptr.h"

#include <AudioToolbox/AudioToolbox.h>
#include <chaining/yas_chaining_umbrella.h>
#include <optional>
#include <ostream>
#include <string>
#include <vector>
#include "yas_audio_engine_ptr.h"
#include "yas_audio_format.h"
#include "yas_audio_types.h"

namespace yas::audio {
class mac_device_global;

struct device {
    class stream;

    using stream_ptr = std::shared_ptr<stream>;

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

    static std::vector<device_ptr> all_devices();
    static std::vector<device_ptr> output_devices();
    static std::vector<device_ptr> input_devices();
    static std::optional<device_ptr> default_system_output_device();
    static std::optional<device_ptr> default_output_device();
    static std::optional<device_ptr> default_input_device();
    static std::optional<device_ptr> device_for_id(AudioDeviceID const);
    static std::optional<size_t> index_of_device(device_ptr const &);
    static bool is_available_device(device_ptr const &);

    AudioDeviceID audio_device_id() const;
    CFStringRef name() const;
    CFStringRef manufacture() const;
    std::vector<stream_ptr> input_streams() const;
    std::vector<stream_ptr> output_streams() const;
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
    static chaining::notifier_ptr<chaining_system_pair_t> &system_notifier();

    using listener_f =
        std::function<void(uint32_t const in_number_addresses, const AudioObjectPropertyAddress *const in_addresses)>;

    bool operator==(device const &) const;
    bool operator!=(device const &) const;

   protected:
    explicit device(AudioDeviceID const device_id);

   private:
    AudioDeviceID const _audio_device_id;
    std::unordered_map<AudioStreamID, stream_ptr> _input_streams_map;
    std::unordered_map<AudioStreamID, stream_ptr> _output_streams_map;
    chaining::notifier_ptr<audio::device::chaining_pair_t> _notifier =
        chaining::notifier<audio::device::chaining_pair_t>::make_shared();
    std::optional<audio::format> _input_format = std::nullopt;
    std::optional<audio::format> _output_format = std::nullopt;
    mutable std::recursive_mutex _mutex;

    void _set_input_format(std::optional<audio::format> const &format);
    void _set_output_format(std::optional<audio::format> const &format);

    listener_f _listener();
    void _udpate_streams(AudioObjectPropertyScope const scope);
    void _update_format(AudioObjectPropertyScope const scope);

    device(device &&) = delete;
    device &operator=(device &&) = delete;
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

#include "yas_audio_mac_device_stream.h"

#endif
