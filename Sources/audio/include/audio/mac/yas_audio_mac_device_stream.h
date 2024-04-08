//
//  yas_audio_mac_device_stream.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <audio/mac/yas_audio_mac_device.h>

#include <ostream>

namespace yas::audio {
struct mac_device::stream {
    enum class property : uint32_t {
        virtual_format = 0,
        is_active,
        starting_channel,
    };

    enum class method { did_change };

    struct property_info {
        AudioObjectID const object_id;
        stream::property const property;
        AudioObjectPropertyAddress const address;

        bool operator<(property_info const &info) const;
    };

    struct change_info {
        std::vector<property_info> const property_infos;

        change_info(std::vector<property_info> &&);
    };

    using observing_pair_t = std::pair<method, change_info>;

    struct args {
        AudioStreamID stream_id;
        AudioDeviceID device_id;
    };

    [[nodiscard]] AudioStreamID stream_id() const;
    [[nodiscard]] std::optional<audio::mac_device_ptr> device() const;
    [[nodiscard]] bool is_active() const;
    [[nodiscard]] audio::direction direction() const;
    [[nodiscard]] audio::format virtual_format() const;
    [[nodiscard]] uint32_t starting_channel() const;

    [[nodiscard]] observing::endable observe(observing::caller<observing_pair_t>::handler_f &&);

    bool operator==(stream const &) const;
    bool operator!=(stream const &) const;

   private:
    using listener_f =
        std::function<void(uint32_t const in_number_addresses, const AudioObjectPropertyAddress *const in_addresses)>;

    std::weak_ptr<stream> _weak_stream;
    AudioStreamID _stream_id;
    AudioDeviceID _device_id;
    observing::notifier_ptr<observing_pair_t> _notifier = observing::notifier<observing_pair_t>::make_shared();

    explicit stream(args &&args);

    void _prepare(mac_device::stream_ptr const &);
    listener_f _listener();
    void _add_listener(AudioObjectPropertySelector const &selector, listener_f handler);

    template <typename T>
    std::unique_ptr<std::vector<T>> _property_data(AudioStreamID const stream_id,
                                                   AudioObjectPropertySelector const selector) const;

   public:
    static mac_device::stream_ptr make_shared(mac_device::stream::args);
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::mac_device::stream::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::mac_device::stream::method const &);

#include "yas_audio_mac_device_stream_private.h"

#endif
