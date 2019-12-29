//
//  yas_audio_ios_session.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <chaining/yas_chaining_umbrella.h>
#include <cstdint>
#include "yas_audio_ptr.h"

namespace yas::audio {
struct ios_session {
    enum method {
        route_change,
        media_service_were_lost,
        media_service_were_reset,
    };

    [[nodiscard]] double sample_rate() const;

    [[nodiscard]] uint32_t output_channel_count() const;
    [[nodiscard]] uint32_t input_channel_count() const;

    chaining::chain_unsync_t<method> chain();

    [[nodiscard]] static ios_session_ptr make_shared();

   private:
    class impl;

    std::unique_ptr<impl> _impl;
    chaining::notifier_ptr<method> _notifier;

    ios_session();
};
}  // namespace yas::audio

#endif
