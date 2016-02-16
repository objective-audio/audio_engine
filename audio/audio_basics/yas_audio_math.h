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
        static Float64 constexpr two_pi = M_PI * 2.0;

        template <typename T>
        static auto decibel_from_linear(T const linear) -> T;

        template <typename T>
        static auto linear_from_decibel(T const decibel) -> T;

        template <typename T>
        static auto tempo_from_seconds(T const seconds) -> T;

        template <typename T>
        static auto seconds_from_tempo(T const tempo) -> T;

        static Float64 seconds_from_frames(const UInt32 frames, Float64 const sample_rate);
        static UInt32 frames_from_seconds(Float64 const seconds, Float64 const sample_rate);

        template <typename T>
        static auto fill_sine(T *const out_data, const UInt32 length, Float64 const start_phase,
                              Float64 const phase_per_frame) -> T;
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
        duration(Float64 const val);

        bool operator==(duration const &) const;
        bool operator!=(duration const &) const;

        void set_seconds(Float64 const val);
        Float64 seconds() const;

        void set_tempo(Float64 const val);
        Float64 tempo() const;

       private:
        Float64 _value;
    };
}
}