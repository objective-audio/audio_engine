//
//  yas_audio_au_mixer.h
//

#pragma once

#include "yas_base.h"

namespace yas {
namespace audio {
    namespace engine {
        class au;

        class au_mixer : public base {
           public:
            au_mixer();
            au_mixer(std::nullptr_t);

            virtual ~au_mixer() final;

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

            audio::engine::au const &au() const;
            audio::engine::au &au();

           private:
            class impl;
        };
    }
}
}