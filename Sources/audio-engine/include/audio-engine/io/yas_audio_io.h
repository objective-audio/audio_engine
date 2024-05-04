//
//  yas_audio_io.h
//

#pragma once

#include <audio-engine/common/yas_audio_ptr.h>
#include <audio-engine/common/yas_audio_time.h>
#include <audio-engine/common/yas_audio_types.h>
#include <audio-engine/io/yas_audio_io_device.h>
#include <audio-engine/io/yas_audio_io_kernel.h>

#include <observing/yas_observing_umbrella.hpp>

namespace yas::audio {
struct io final {
    enum class running_method {
        will_start,
        did_stop,
    };

    enum class device_method {
        initial,
        changed,
        updated,
    };

    using device_observing_pair_t = std::pair<device_method, std::optional<io_device_ptr>>;

    ~io();

    void set_device(std::optional<io_device_ptr> const &);
    [[nodiscard]] std::optional<io_device_ptr> const &device() const;
    [[nodiscard]] bool is_running() const;
    [[nodiscard]] bool is_interrupting() const;
    void set_render_handler(std::optional<io_render_f>);
    void set_maximum_frames_per_slice(uint32_t const);
    [[nodiscard]] uint32_t maximum_frames_per_slice() const;

    void start();
    void stop();

    observing::endable observe_running(std::function<void(running_method const &)> &&);
    observing::syncable observe_device(observing::caller<device_observing_pair_t>::handler_f &&);

    [[nodiscard]] static io_ptr make_shared(std::optional<io_device_ptr> const &);

   private:
    std::optional<io_device_ptr> _device;
    std::optional<io_core_ptr> _io_core = std::nullopt;
    bool _is_running = false;
    std::optional<io_render_f> _render_handler = std::nullopt;
    uint32_t _maximum_frames = 4096;

    observing::notifier_ptr<running_method> const _running_notifier =
        observing::notifier<running_method>::make_shared();
    observing::fetcher_ptr<device_observing_pair_t> _device_fetcher;
    observing::cancellable_ptr _device_updated_canceller;
    observing::cancellable_ptr _interruption_canceller;

    io(std::optional<io_device_ptr> const &);

    void _initialize();
    void _uninitialize();

    void _reload();
    void _stop_io_core();
    void _start_io_core();

    void _setup_interruption_observer();
    void _dispose_interruption_observer();
};
}  // namespace yas::audio
