//
//  yas_audio_interruptor.h
//

#pragma once

#include <observing/yas_observing_umbrella.hpp>

namespace yas::audio {
enum interruption_method {
    began,
    ended,
};

struct interruptor {
    virtual ~interruptor() = default;

    [[nodiscard]] virtual bool is_interrupting() const = 0;

    [[nodiscard]] virtual observing::endable observe_interruption(
        observing::caller<interruption_method>::handler_f &&) = 0;
};
}  // namespace yas::audio
