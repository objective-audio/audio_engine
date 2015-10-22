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
#include "yas_weak.h"
#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <vector>
#include <set>

namespace yas
{
    namespace audio_device_stream_method
    {
        static const auto stream_did_change = "yas.audio_device_stream.stream_did_change";
    }

    class audio_device;

    class audio_device_stream
    {
       public:
        enum class property : UInt32 {
            virtual_format = 0,
            is_active,
            starting_channel,
        };

        class property_info
        {
           public:
            const AudioObjectID object_id;
            const audio_device_stream::property property;
            const AudioObjectPropertyAddress address;

            property_info(const audio_device_stream::property property, const AudioObjectID object_id,
                          const AudioObjectPropertyAddress &address);

            bool operator<(const property_info &info) const;
        };

        using property_infos_sptr = std::shared_ptr<std::set<property_info>>;

        audio_device_stream(std::nullptr_t n = nullptr);
        audio_device_stream(const AudioStreamID, const AudioDeviceID);

        ~audio_device_stream() = default;

        audio_device_stream(const audio_device_stream &) = default;
        audio_device_stream(audio_device_stream &&) = default;
        audio_device_stream &operator=(const audio_device_stream &) = default;
        audio_device_stream &operator=(audio_device_stream &&) = default;

        explicit operator bool() const;

        bool operator==(const audio_device_stream &);
        bool operator!=(const audio_device_stream &);

        AudioStreamID stream_id() const;
        audio_device device() const;
        bool is_active() const;
        direction direction() const;
        audio_format virtual_format() const;
        UInt32 starting_channel() const;

        subject &subject() const;

       private:
        class impl;
        std::shared_ptr<impl> _impl;

        explicit audio_device_stream(const std::shared_ptr<impl> &);

        template <typename T>
        std::unique_ptr<std::vector<T>> _property_data(const AudioStreamID stream_id,
                                                       const AudioObjectPropertySelector selector) const;

        using weak = weak<audio_device_stream>;
        friend weak;
    };
}

#include "yas_audio_device_stream_private.h"

#endif
