//
//  yas_audio_ios_device.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <chaining/yas_chaining_umbrella.h>
#include "yas_audio_format.h"
#include "yas_audio_io_device.h"
#include "yas_audio_ios_io_core.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct ios_device final : io_device {
    double sample_rate() const;

    uint32_t input_channel_count() const override;
    uint32_t output_channel_count() const override;

    std::optional<audio::format> input_format() const override;
    std::optional<audio::format> output_format() const override;

    io_core_ptr make_io_core() const override;

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain() override;

    static ios_device_ptr make_shared();

   private:
    class impl;

    std::unique_ptr<impl> _impl;
    std::weak_ptr<ios_device> _weak_device;
    chaining::notifier_ptr<method> _notifier = chaining::notifier<method>::make_shared();

    ios_device();

    void _prepare(ios_device_ptr const &);
};
}  // namespace yas::audio

#endif
