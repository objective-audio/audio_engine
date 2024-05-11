//
//  math.h
//

#pragma once

#include <cmath>
#include <cstdint>

namespace yas::audio {
namespace math {
    double constexpr two_pi = M_PI * 2.0;

    template <typename T>
    [[nodiscard]] auto decibel_from_linear(T const linear) -> T;

    template <typename T>
    [[nodiscard]] auto linear_from_decibel(T const decibel) -> T;

    template <typename T>
    [[nodiscard]] auto tempo_from_seconds(T const seconds) -> T;

    template <typename T>
    [[nodiscard]] auto seconds_from_tempo(T const tempo) -> T;

    [[nodiscard]] double seconds_from_frames(uint32_t const frames, double const sample_rate);
    [[nodiscard]] uint32_t frames_from_seconds(double const seconds, double const sample_rate);

    template <typename T>
    auto fill_sine(T *const out_data, uint32_t const length, double const start_phase,
                   double const phase_per_frame) -> T;
};  // namespace math

template <typename T>
class level {
   public:
    level();
    level(T const val);

    bool operator==(level const &) const;
    bool operator!=(level const &) const;

    void set_linear(T const val);
    [[nodiscard]] T linear() const;

    void set_decibel(T const val);
    [[nodiscard]] T decibel() const;

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
    [[nodiscard]] double seconds() const;

    void set_tempo(double const val);
    [[nodiscard]] double tempo() const;

   private:
    double _value;
};
}  // namespace yas::audio
