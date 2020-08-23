//
//  yas_audio_sample_kernel.h
//

#pragma once

#include <audio/yas_audio_umbrella.h>
#include <Accelerate/Accelerate.h>

namespace yas::audio::sample {
    class kernel;
    using kernel_ptr = std::shared_ptr<kernel>;
}

namespace yas::audio::sample {
struct kernel {
    kernel() : _phase(0), _sine_data(_sineDataMaxCount) {
        _through_volume.store(0);
        _sine_frequency.store(1000.0);
        _sine_volume.store(0.0);
    }

    void set_througn_volume(double value) {
        _through_volume.store(value);
    }

    double through_volume() const {
        return _through_volume.load();
    }

    void set_sine_frequency(double value) {
        _sine_frequency.store(value);
    }

    double sine_frequency() const {
        return _sine_frequency.load();
    }

    void set_sine_volume(double value) {
        _sine_volume.store(value);
    }

    double sine_volume() const {
        return _sine_volume.load();
    }

    void process(std::optional<audio::pcm_buffer_ptr> const &input_buffer_opt, std::optional<audio::pcm_buffer_ptr> const &output_buffer_opt) {
        if (!output_buffer_opt) {
            return;
        }
        
        auto const &output_buffer = output_buffer_opt.value();
        
        uint32_t const frame_length = output_buffer->frame_length();

        if (frame_length == 0) {
            return;
        }

        auto const &format = output_buffer->format();
        if (format.pcm_format() == audio::pcm_format::float32 && format.stride() == 1) {
            if (input_buffer_opt) {
                auto const &input_buffer = *input_buffer_opt;
                
                if (input_buffer->frame_length() >= frame_length) {
                    output_buffer->copy_from(*input_buffer);

                    float const throughVol = through_volume();

                    auto each = audio::make_each_data<float>(*output_buffer);
                    while (yas_each_data_next_ch(each)) {
                        cblas_sscal(frame_length, throughVol, yas_each_data_ptr(each), 1);
                    }
                }
            }

            double const sample_rate = format.sample_rate();
            double const start_phase = _phase;
            double const sine_vol = sine_volume();
            double const freq = sine_frequency();

            if (frame_length < _sineDataMaxCount) {
                _phase = audio::math::fill_sine(&_sine_data[0], frame_length, start_phase,
                                                freq / sample_rate * audio::math::two_pi);

                auto each = audio::make_each_data<float>(*output_buffer);
                while (yas_each_data_next_ch(each)) {
                    cblas_saxpy(frame_length, sine_vol, &_sine_data[0], 1, yas_each_data_ptr(each), 1);
                }
            }
        }
    }
    
    static sample::kernel_ptr make_shared() {
        return std::make_shared<audio::sample::kernel>();
    }

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
}
