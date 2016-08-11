//
//  yas_audio_unit_mixer_extension.h
//

#pragma once

#include "yas_base.h"

namespace yas {
namespace audio {
    class unit_extension;

    class unit_mixer_extension : public base {
       public:
        unit_mixer_extension();
        unit_mixer_extension(std::nullptr_t);

        virtual ~unit_mixer_extension() final;

        void set_output_volume(float const volume, uint32_t const bus_idx);
        float output_volume(uint32_t const bus_idx) const;
        void set_output_pan(float const pan, uint32_t const bus_idx);
        float output_pan(uint32_t const bus_idx) const;

        void set_input_volume(float const volume, uint32_t const bus_idx);
        float input_volume(uint32_t const bus_idx) const;
        void set_input_pan(float const pan, uint32_t const bus_idx);
        float input_pan(uint32_t const bus_idx) const;

        void set_input_enabled(bool const enabled, uint32_t const bus_idx);
        bool input_enabled(uint32_t const bus_idx) const;

        audio::unit_extension const &unit_extension() const;
        audio::unit_extension &unit_extension();

       private:
        class impl;
    };
}
}
