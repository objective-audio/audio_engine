//
//  yas_audio_device_stream.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_observing.h"

class yas::audio::device::stream : public base {
    using super_class = base;
    class impl;

   public:
    enum class property : UInt32 {
        virtual_format = 0,
        is_active,
        starting_channel,
    };

    static auto constexpr stream_did_change_key = "yas.audio.device.stream.stream_did_change";

    struct property_info {
        AudioObjectID const object_id;
        stream::property const property;
        AudioObjectPropertyAddress const address;

        property_info(stream::property const property, AudioObjectID const object_id,
                      AudioObjectPropertyAddress const &address);

        bool operator<(property_info const &info) const;
    };

    struct change_info {
        std::vector<property_info> const property_infos;

        change_info(std::vector<property_info> &&);
    };

    stream(std::nullptr_t);
    stream(AudioStreamID const, AudioDeviceID const);

    ~stream();

    stream(stream const &) = default;
    stream(stream &&) = default;
    stream &operator=(stream const &) = default;
    stream &operator=(stream &&) = default;

    bool operator==(stream const &) const;
    bool operator!=(stream const &) const;

    AudioStreamID stream_id() const;
    audio::device device() const;
    bool is_active() const;
    direction direction() const;
    audio::format virtual_format() const;
    UInt32 starting_channel() const;

    yas::subject<change_info> &subject() const;

   private:
    template <typename T>
    std::unique_ptr<std::vector<T>> _property_data(AudioStreamID const stream_id,
                                                   AudioObjectPropertySelector const selector) const;
};

#include "yas_audio_device_stream_private.h"

#endif
