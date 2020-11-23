//
//  yas_audio_mac_device.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <audio/yas_audio_io_device.h>

namespace yas::audio {
struct mac_device : io_device {
    class stream;

    using stream_ptr = std::shared_ptr<stream>;

    enum class property : uint32_t {
        system,
        stream,
        format,
    };

    struct property_info {
        AudioObjectID const object_id;
        mac_device::property const property;
        AudioObjectPropertyAddress const address;

        bool operator<(property_info const &info) const;
    };

    struct change_info {
        std::vector<property_info> const property_infos;
    };

    [[nodiscard]] static std::vector<mac_device_ptr> all_devices();
    [[nodiscard]] static std::vector<mac_device_ptr> output_devices();
    [[nodiscard]] static std::vector<mac_device_ptr> input_devices();
    [[nodiscard]] static std::optional<mac_device_ptr> default_system_output_device();
    [[nodiscard]] static std::optional<mac_device_ptr> default_output_device();
    [[nodiscard]] static std::optional<mac_device_ptr> default_input_device();
    [[nodiscard]] static io_device_ptr renewable_default_output_device();
    [[nodiscard]] static std::optional<mac_device_ptr> device_for_id(AudioDeviceID const);
    [[nodiscard]] static std::optional<size_t> index_of_device(mac_device_ptr const &);
    [[nodiscard]] static bool is_available_device(mac_device_ptr const &);

    [[nodiscard]] AudioDeviceID audio_device_id() const;
    [[nodiscard]] std::string name() const;
    [[nodiscard]] std::string manufacture() const;
    [[nodiscard]] std::vector<stream_ptr> input_streams() const;
    [[nodiscard]] std::vector<stream_ptr> output_streams() const;
    [[nodiscard]] double nominal_sample_rate() const;

    [[nodiscard]] std::optional<audio::format> input_format() const override;
    [[nodiscard]] std::optional<audio::format> output_format() const override;

    [[nodiscard]] chaining::chain_unsync_t<change_info> chain() const;
    [[nodiscard]] static chaining::chain_unsync_t<change_info> system_chain();

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain() override;

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
    chaining::notifier_ptr<audio::mac_device::change_info> _notifier =
        chaining::notifier<audio::mac_device::change_info>::make_shared();
    chaining::notifier_ptr<io_device::method> _io_device_notifier =
        chaining::notifier<io_device::method>::make_shared();
    chaining::observer_pool _io_pool;
    std::optional<audio::format> _input_format = std::nullopt;
    std::optional<audio::format> _output_format = std::nullopt;

    listener_f _listener();
    void _udpate_streams(AudioObjectPropertyScope const scope);
    void _update_format(AudioObjectPropertyScope const scope);

    mac_device(mac_device &&) = delete;
    mac_device &operator=(mac_device &&) = delete;
    mac_device(mac_device const &) = delete;
    mac_device &operator=(mac_device const &) = delete;

    std::optional<interruptor_ptr> const &interruptor() const override;

    io_core_ptr make_io_core() const override;
};
}  // namespace yas::audio

#include <audio/yas_audio_mac_device_stream.h>

#endif
