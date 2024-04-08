//
//  yas_audio_ios_device.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <audio/io/yas_audio_io_device.h>
#include <audio/ios/yas_audio_ios_session.h>

namespace yas::audio {
struct ios_device final : io_device {
    std::optional<ios_device_session_ptr> const &session() const;

    [[nodiscard]] double sample_rate() const;

    [[nodiscard]] std::optional<audio::format> input_format() const override;
    [[nodiscard]] std::optional<audio::format> output_format() const override;

    [[nodiscard]] observing::endable observe_io_device(observing::caller<method>::handler_f &&) override;

    [[nodiscard]] static ios_device_ptr make_shared(ios_session_ptr const &);
    [[nodiscard]] static ios_device_ptr make_shared(ios_device_session_ptr const &, interruptor_ptr const &);

    [[nodiscard]] static io_device_ptr make_renewable_device(ios_session_ptr const &);

   private:
    class impl;

    std::weak_ptr<ios_device> _weak_device;
    std::optional<ios_device_session_ptr> _session;
    std::optional<audio::interruptor_ptr> _interruptor;
    observing::notifier_ptr<method> const _notifier = observing::notifier<method>::make_shared();
    observing::cancellable_ptr _canceller;

    ios_device(ios_device_session_ptr const &, interruptor_ptr const &);

    std::optional<interruptor_ptr> const &interruptor() const override;

    io_core_ptr make_io_core() const override;
};
}  // namespace yas::audio

#endif
