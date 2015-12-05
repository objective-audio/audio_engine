//
//  yas_audio_device_stream.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_types.h"
#include "yas_observing.h"
#include "yas_audio_format.h"
#include "yas_base.h"
#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <vector>
#include <set>

namespace yas
{
    namespace audio
    {
        class device;
    }

    class audio_device_stream : public base
    {
        using super_class = base;
        class impl;

       public:
        enum class property : UInt32 {
            virtual_format = 0,
            is_active,
            starting_channel,
        };

        constexpr static auto stream_did_change_key = "yas.audio_device_stream.stream_did_change";

        struct property_info {
            const AudioObjectID object_id;
            const audio_device_stream::property property;
            const AudioObjectPropertyAddress address;

            property_info(const audio_device_stream::property property, const AudioObjectID object_id,
                          const AudioObjectPropertyAddress &address);

            bool operator<(const property_info &info) const;
        };

        struct change_info {
            const std::vector<property_info> property_infos;

            change_info(std::vector<property_info> &&);
        };

        audio_device_stream(std::nullptr_t);
        audio_device_stream(const AudioStreamID, const AudioDeviceID);

        ~audio_device_stream();

        audio_device_stream(const audio_device_stream &) = default;
        audio_device_stream(audio_device_stream &&) = default;
        audio_device_stream &operator=(const audio_device_stream &) = default;
        audio_device_stream &operator=(audio_device_stream &&) = default;

        bool operator==(const audio_device_stream &) const;
        bool operator!=(const audio_device_stream &) const;

        AudioStreamID stream_id() const;
        audio::device device() const;
        bool is_active() const;
        direction direction() const;
        audio::format virtual_format() const;
        UInt32 starting_channel() const;

        subject<change_info> &subject() const;

       private:
        template <typename T>
        std::unique_ptr<std::vector<T>> _property_data(const AudioStreamID stream_id,
                                                       const AudioObjectPropertySelector selector) const;
    };
}

#include "yas_audio_device_stream_private.h"

#endif
