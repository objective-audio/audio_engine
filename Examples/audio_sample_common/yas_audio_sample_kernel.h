//
//  yas_audio_sample_kernel.h
//

#pragma once

#include <audio-engine/yas_audio_engine_umbrella.hpp>

namespace yas::audio::sample {
class kernel;
using kernel_ptr = std::shared_ptr<kernel>;
}  // namespace yas::audio::sample

namespace yas::audio::sample {
struct kernel {
    [[nodiscard]] static sample::kernel_ptr make_shared();

    kernel();

    void set_througn_volume(double);
    [[nodiscard]] double through_volume() const;

    void set_sine_frequency(double value);
    [[nodiscard]] double sine_frequency() const;

    void set_sine_volume(double value);
    [[nodiscard]] double sine_volume() const;

    void process(audio::pcm_buffer const *const input_buffer, audio::pcm_buffer *const output_buffer);

   private:
    static uint32_t const _sineDataMaxCount = 4096;

    std::atomic<double> _through_volume;
    std::atomic<double> _sine_frequency;
    std::atomic<double> _sine_volume;

    double _phase;
    std::vector<float> _sine_data;

    kernel(const kernel &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(const kernel &) = delete;
    kernel &operator=(kernel &&) = delete;
};
}  // namespace yas::audio::sample
