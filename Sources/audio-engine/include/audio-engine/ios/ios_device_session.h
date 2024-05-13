//
//  ios_device_session.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <cstdint>
#include <observing/umbrella.hpp>

namespace yas::audio {
struct ios_device_session {
    enum device_method {
        activate,
        deactivate,
        route_change,
        media_service_were_lost,
        media_service_were_reset,
    };

    virtual ~ios_device_session() = default;

    [[nodiscard]] virtual double sample_rate() const = 0;
    [[nodiscard]] virtual uint32_t output_channel_count() const = 0;
    [[nodiscard]] virtual uint32_t input_channel_count() const = 0;

    [[nodiscard]] virtual observing::endable observe_device(observing::caller<device_method>::handler_f &&) = 0;
};
}  // namespace yas::audio

#endif
