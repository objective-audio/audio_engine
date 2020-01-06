//
//  yas_audio_offline_device.h
//

#pragma once

#include "yas_audio_io_device.h"

namespace yas::audio {
struct offline_render_args {
    audio::pcm_buffer_ptr const &buffer;
    audio::time const &when;
};

using offline_render_f = std::function<continuation(offline_render_args)>;
using offline_completion_f = std::function<void(bool const cancelled)>;

struct offline_device : io_device {
    [[nodiscard]] std::optional<audio::format> input_format() const override;
    [[nodiscard]] std::optional<audio::format> output_format() const override;

    [[nodiscard]] io_core_ptr make_io_core() const override;

    [[nodiscard]] std::optional<interruptor_ptr> const &interruptor() const override;

    [[nodiscard]] chaining::chain_unsync_t<io_device::method> io_device_chain() override;

    [[nodiscard]] offline_render_f render_handler() const;
    [[nodiscard]] std::optional<offline_completion_f> completion_handler() const;

    static offline_device_ptr make_shared(audio::format const &output_format, offline_render_f &&,
                                          offline_completion_f &&);

   private:
    std::weak_ptr<offline_device> _weak_device;
    audio::format const _output_format;
    offline_render_f _render_handler;
    std::optional<offline_completion_f> _completion_handler;

    chaining::notifier_ptr<io_device::method> _notifier = chaining::notifier<io_device::method>::make_shared();

    offline_device(audio::format const &output_format, offline_render_f &&, offline_completion_f &&);

    void _prepare(offline_device_ptr const &);
};
}  // namespace yas::audio
