//
//  yas_audio_renewable_device.h
//

#pragma once

#include "yas_audio_io_device.h"

namespace yas::audio {
struct renewable_device : io_device {
    using device_f = std::function<io_device_ptr(void)>;

    enum method {
        notify,
        renewal,
    };

    using method_f = std::function<void(method const &)>;
    using renewal_f = std::function<chaining::invalidatable_ptr(io_device_ptr const &, method_f const &)>;

    [[nodiscard]] std::optional<audio::format> input_format() const override;
    [[nodiscard]] std::optional<audio::format> output_format() const override;

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain() override;

    [[nodiscard]] static renewable_device_ptr make_shared(device_f const &, renewal_f const &);

   private:
    device_f const _device_handler;
    renewal_f const _renewal_handler;
    audio::io_device_ptr _device;
    chaining::notifier_ptr<audio::io_device::method> _notifier;
    chaining::invalidatable_ptr _observer;

    renewable_device(device_f const &, renewal_f const &);

    io_core_ptr make_io_core() const override;

    void _renewal_device();
};
}  // namespace yas::audio
