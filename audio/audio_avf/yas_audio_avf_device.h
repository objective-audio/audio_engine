//
//  yas_audio_avf_device.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_format.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct avf_device final {
    enum class method { lost, route_change };

    double sample_rate() const;

    uint32_t input_channel_count() const;
    uint32_t output_channel_count() const;

    std::optional<audio::format> input_format() const;
    std::optional<audio::format> output_format() const;

    static avf_device_ptr make_shared();

    [[nodiscard]] chaining::chain_unsync_t<method> chain();

   private:
    class impl;

    std::unique_ptr<impl> _impl;

    chaining::notifier_ptr<audio::avf_device::method> _notifier =
        chaining::notifier<audio::avf_device::method>::make_shared();

    avf_device();

    void _prepare(avf_device_ptr const &);
};
}  // namespace yas::audio

#endif
