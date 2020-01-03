//
//  yas_audio_mac_empty_device.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_io.h"

namespace yas::audio {
struct mac_empty_device : io_device {
    static mac_empty_device_ptr make_shared();

   private:
    mac_empty_device();

    chaining::notifier_ptr<audio::io_device::method> _notifier;

    std::optional<audio::format> input_format() const override;
    std::optional<audio::format> output_format() const override;

    std::optional<interruptor_ptr> const &interruptor() const override;

    io_core_ptr make_io_core() const override;

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain() override;
};
}  // namespace yas::audio

#endif
