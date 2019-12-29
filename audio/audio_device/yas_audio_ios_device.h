//
//  yas_audio_ios_device.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include "yas_audio_io_device.h"

namespace yas::audio {
struct ios_device final : io_device {
    [[nodiscard]] double sample_rate() const;

    [[nodiscard]] std::optional<audio::format> input_format() const override;
    [[nodiscard]] std::optional<audio::format> output_format() const override;

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain() override;

    [[nodiscard]] static ios_device_ptr make_shared();

   private:
    class impl;

    std::weak_ptr<ios_device> _weak_device;
    ios_session_ptr _session;
    chaining::notifier_ptr<method> _notifier = chaining::notifier<method>::make_shared();
    chaining::any_observer_ptr _observer;

    ios_device();

    io_core_ptr make_io_core() const override;
};
}  // namespace yas::audio

#endif
