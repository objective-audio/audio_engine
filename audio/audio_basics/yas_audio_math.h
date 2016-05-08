//
//  yas_audio_math.h
//

#pragma once

#include <MacTypes.h>
#include <math.h>

namespace yas {
namespace audio {
    class math {
       public:
        static double constexpr two_pi = M_PI * 2.0;

        template <typename T>
        static auto decibel_from_linear(T const linear) -> T;

        template <typename T>
        static auto linear_from_decibel(T const decibel) -> T;

        template <typename T>
        static auto tempo_from_seconds(T const seconds) -> T;

        template <typename T>
        static auto seconds_from_tempo(T const tempo) -> T;

        static double seconds_from_frames(const uint32_t frames, double const sample_rate);
        static uint32_t frames_from_seconds(double const seconds, double const sample_rate);

        template <typename T>
        static auto fill_sine(T *const out_data, const uint32_t length, double const start_phase,
                              double const phase_per_frame) -> T;
    };

    template <typename T>
    class level {
       public:
        level();
        level(T const val);

        bool operator==(level const &) const;
        bool operator!=(level const &) const;

        void set_linear(T const val);
        T linear() const;

        void set_decibel(T const val);
        T decibel() const;

       private:
        T _value;
    };

    class duration {
       public:
        duration();
        duration(double const val);

        bool operator==(duration const &) const;
        bool operator!=(duration const &) const;

        void set_seconds(double const val);
        double seconds() const;

        void set_tempo(double const val);
        double tempo() const;

       private:
        double _value;
    };
}
}