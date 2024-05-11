//
//  yas_audio_sample_kernel.cpp
//

#include "yas_audio_sample_kernel.h"

#include <Accelerate/Accelerate.h>

using namespace yas;
using namespace yas::audio;
using namespace yas::audio::sample;

sample::kernel_ptr kernel::make_shared() {
    return std::make_shared<audio::sample::kernel>();
}

kernel::kernel() : _phase(0), _sine_data(_sineDataMaxCount) {
    _through_volume.store(0);
    _sine_frequency.store(1000.0);
    _sine_volume.store(0.0);
}

void kernel::set_througn_volume(double value) {
    _through_volume.store(value);
}

double kernel::through_volume() const {
    return _through_volume.load();
}

void kernel::set_sine_frequency(double value) {
    _sine_frequency.store(value);
}

double kernel::sine_frequency() const {
    return _sine_frequency.load();
}

void kernel::set_sine_volume(double value) {
    _sine_volume.store(value);
}

double kernel::sine_volume() const {
    return _sine_volume.load();
}

void kernel::process(audio::pcm_buffer const *const input_buffer, audio::pcm_buffer *const output_buffer) {
    if (!output_buffer) {
        return;
    }

    uint32_t const frame_length = output_buffer->frame_length();

    if (frame_length == 0) {
        return;
    }

    auto const &format = output_buffer->format();
    if (format.pcm_format() == audio::pcm_format::float32 && format.stride() == 1) {
        if (input_buffer) {
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
