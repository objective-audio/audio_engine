//
//  yas_audio_renewable_device.h
//

#pragma once

#include <audio/yas_audio_io_device.h>

namespace yas::audio {
struct renewable_device : io_device {
    using device_f = std::function<io_device_ptr(void)>;

    enum method {
        notify,
        renewal,
    };

    using method_f = std::function<void(method const &)>;
    using renewal_f = std::function<std::vector<observing::cancellable_ptr>(io_device_ptr const &, method_f const &)>;

    [[nodiscard]] std::optional<audio::format> input_format() const override;
    [[nodiscard]] std::optional<audio::format> output_format() const override;

    [[nodiscard]] observing::canceller_ptr observe_io_device(
        observing::caller<io_device::method>::handler_f &&) override;

    [[nodiscard]] static renewable_device_ptr make_shared(device_f const &, renewal_f const &);

   private:
    device_f const _device_handler;
    renewal_f const _renewal_handler;
    audio::io_device_ptr _device;
    observing::notifier_ptr<io_device::method> const _notifier =
        observing::notifier<audio::io_device::method>::make_shared();
    std::vector<observing::cancellable_ptr> _observers;

    renewable_device(device_f const &, renewal_f const &);

    std::optional<interruptor_ptr> const &interruptor() const override;

    io_core_ptr make_io_core() const override;

    void _renewal_device();
};
}  // namespace yas::audio
