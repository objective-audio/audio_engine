//
//  yas_audio_device_stream.h
//  Copyright (c) 2015 Yuki Yasoshima.
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

    constexpr static auto stream_did_change_key = "yas.audio.device.stream.stream_did_change";

    struct property_info {
        const AudioObjectID object_id;
        const stream::property property;
        const AudioObjectPropertyAddress address;

        property_info(const stream::property property, const AudioObjectID object_id,
                      const AudioObjectPropertyAddress &address);

        bool operator<(const property_info &info) const;
    };

    struct change_info {
        const std::vector<property_info> property_infos;

        change_info(std::vector<property_info> &&);
    };

    stream(std::nullptr_t);
    stream(const AudioStreamID, const AudioDeviceID);

    ~stream();

    stream(const stream &) = default;
    stream(stream &&) = default;
    stream &operator=(const stream &) = default;
    stream &operator=(stream &&) = default;

    bool operator==(const stream &) const;
    bool operator!=(const stream &) const;

    AudioStreamID stream_id() const;
    audio::device device() const;
    bool is_active() const;
    direction direction() const;
    audio::format virtual_format() const;
    UInt32 starting_channel() const;

    yas::subject<change_info> &subject() const;

   private:
    template <typename T>
    std::unique_ptr<std::vector<T>> _property_data(const AudioStreamID stream_id,
                                                   const AudioObjectPropertySelector selector) const;
};

#include "yas_audio_device_stream_private.h"

#endif
