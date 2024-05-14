//
//  mac_empty_device.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <audio-engine/io/io.h>

namespace yas::audio {
struct mac_empty_device : io_device {
    [[nodiscard]] static mac_empty_device_ptr make_shared();

   private:
    mac_empty_device();

    observing::notifier_ptr<method> const _notifier = observing::notifier<method>::make_shared();

    std::optional<audio::format> input_format() const override;
    std::optional<audio::format> output_format() const override;

    std::optional<interruptor_ptr> const &interruptor() const override;

    io_core_ptr make_io_core() const override;

    [[nodiscard]] observing::endable observe_io_device(observing::caller<method>::handler_f &&) override;
};
}  // namespace yas::audio

#endif
