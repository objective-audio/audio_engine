//
//  yas_audio_device_stream.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

namespace yas {
template <typename T, typename K>
class subject;

namespace audio {
    class device::stream : public base {
        class impl;

       public:
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

            property_info(stream::property const property, AudioObjectID const object_id,
                          AudioObjectPropertyAddress const &address);

            bool operator<(property_info const &info) const;
        };

        struct change_info {
            std::vector<property_info> const property_infos;

            change_info(std::vector<property_info> &&);
        };

        using subject_t = yas::subject<change_info, method>;

        struct args {
            AudioStreamID stream_id;
            AudioDeviceID device_id;
        };

        stream(args args);
        stream(std::nullptr_t);

        AudioStreamID stream_id() const;
        audio::device device() const;
        bool is_active() const;
        direction direction() const;
        audio::format virtual_format() const;
        uint32_t starting_channel() const;

        subject_t &subject() const;

       private:
        template <typename T>
        std::unique_ptr<std::vector<T>> _property_data(AudioStreamID const stream_id,
                                                       AudioObjectPropertySelector const selector) const;
    };
}
}

#include "yas_audio_device_stream_private.h"

#endif
