//
//  yas_audio_device_stream.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import <cpp_utils/yas_weakable.h>
#include <ostream>
#import "yas_audio_device.h"

namespace yas::audio {
struct device::stream : weakable<device::stream> {
    class impl;

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

    using chaining_pair_t = std::pair<method, change_info>;

    struct args {
        AudioStreamID stream_id;
        AudioDeviceID device_id;
    };

    explicit stream(args args);
    explicit stream(std::shared_ptr<impl> &&);

    AudioStreamID stream_id() const;
    std::shared_ptr<audio::device> device() const;
    bool is_active() const;
    audio::direction direction() const;
    audio::format virtual_format() const;
    uint32_t starting_channel() const;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<change_info, chaining_pair_t> chain(method const) const;

    bool operator==(stream const &) const;
    bool operator!=(stream const &) const;

    std::shared_ptr<weakable_impl> weakable_impl_ptr() const override;

   private:
    std::shared_ptr<impl> _impl;

    template <typename T>
    std::unique_ptr<std::vector<T>> _property_data(AudioStreamID const stream_id,
                                                   AudioObjectPropertySelector const selector) const;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::device::stream::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::device::stream::method const &);

#include "yas_audio_device_stream_private.h"

#endif
