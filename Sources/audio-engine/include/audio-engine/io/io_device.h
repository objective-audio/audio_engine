//
//  io_device.h
//

#pragma once

#include <audio-engine/common/interruptor.h>
#include <audio-engine/io/io_core.h>

namespace yas::audio {
struct io_device {
    enum class method { lost, updated };

    [[nodiscard]] virtual std::optional<audio::format> input_format() const = 0;
    [[nodiscard]] virtual std::optional<audio::format> output_format() const = 0;

    [[nodiscard]] virtual io_core_ptr make_io_core() const = 0;

    [[nodiscard]] virtual std::optional<interruptor_ptr> const &interruptor() const = 0;

    [[nodiscard]] virtual observing::endable observe_io_device(observing::caller<method>::handler_f &&) = 0;

    [[nodiscard]] uint32_t input_channel_count() const;
    [[nodiscard]] uint32_t output_channel_count() const;

    [[nodiscard]] bool is_interrupting() const;
    [[nodiscard]] observing::endable observe_interruption(observing::caller<interruption_method>::handler_f &&);

    [[nodiscard]] static io_device_ptr cast(io_device_ptr const &device) {
        return device;
    }
};
}  // namespace yas::audio
