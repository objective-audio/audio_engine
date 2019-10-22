//
//  yas_audio_mac_device.h
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
#include "yas_audio_engine_ptr.h"
#include "yas_audio_format.h"
#include "yas_audio_io_device.h"
#include "yas_audio_types.h"

namespace yas::audio {
class mac_device_global;

struct mac_device : io_device {
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
        mac_device::property const property;
        AudioObjectPropertyAddress const address;

        bool operator<(property_info const &info) const;
    };

    struct change_info {
        std::vector<property_info> const property_infos;
    };

    using chaining_pair_t = std::pair<method, change_info>;
    using chaining_system_pair_t = std::pair<system_method, change_info>;

    static std::vector<mac_device_ptr> all_devices();
    static std::vector<mac_device_ptr> output_devices();
    static std::vector<mac_device_ptr> input_devices();
    static std::optional<mac_device_ptr> default_system_output_device();
    static std::optional<mac_device_ptr> default_output_device();
    static std::optional<mac_device_ptr> default_input_device();
    static std::optional<mac_device_ptr> device_for_id(AudioDeviceID const);
    static std::optional<size_t> index_of_device(mac_device_ptr const &);
    static bool is_available_device(mac_device_ptr const &);

    AudioDeviceID audio_device_id() const;
    CFStringRef name() const;
    CFStringRef manufacture() const;
    std::vector<stream_ptr> input_streams() const;
    std::vector<stream_ptr> output_streams() const;
    double nominal_sample_rate() const;

    std::optional<audio::format> input_format() const override;
    std::optional<audio::format> output_format() const override;
    uint32_t input_channel_count() const override;
    uint32_t output_channel_count() const override;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<change_info, chaining_pair_t> chain(method const) const;
    [[nodiscard]] static chaining::chain_unsync_t<chaining_system_pair_t> system_chain();
    [[nodiscard]] static chaining::chain_relayed_unsync_t<change_info, chaining_system_pair_t> system_chain(
        system_method const);

    io_core_ptr make_io_core() const override;

    // for Test
    static chaining::notifier_ptr<chaining_system_pair_t> &system_notifier();

    using listener_f =
        std::function<void(uint32_t const in_number_addresses, const AudioObjectPropertyAddress *const in_addresses)>;

    bool operator==(mac_device const &) const;
    bool operator!=(mac_device const &) const;

   protected:
    explicit mac_device(AudioDeviceID const device_id);

    void _prepare(mac_device_ptr const &);

   private:
    std::weak_ptr<mac_device> _weak_mac_device;
    AudioDeviceID const _audio_device_id;
    std::unordered_map<AudioStreamID, stream_ptr> _input_streams_map;
    std::unordered_map<AudioStreamID, stream_ptr> _output_streams_map;
    chaining::notifier_ptr<audio::mac_device::chaining_pair_t> _notifier =
        chaining::notifier<audio::mac_device::chaining_pair_t>::make_shared();
    std::optional<audio::format> _input_format = std::nullopt;
    std::optional<audio::format> _output_format = std::nullopt;
    mutable std::recursive_mutex _mutex;

    void _set_input_format(std::optional<audio::format> const &format);
    void _set_output_format(std::optional<audio::format> const &format);

    listener_f _listener();
    void _udpate_streams(AudioObjectPropertyScope const scope);
    void _update_format(AudioObjectPropertyScope const scope);

    mac_device(mac_device &&) = delete;
    mac_device &operator=(mac_device &&) = delete;
    mac_device(mac_device const &) = delete;
    mac_device &operator=(mac_device const &) = delete;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::mac_device::method const &);
std::string to_string(audio::mac_device::system_method const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::mac_device::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::mac_device::system_method const &);

#include "yas_audio_mac_device_stream.h"

#endif
