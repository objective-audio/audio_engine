//
//  yas_audio_ios_session.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include <cpp_utils/yas_result.h>

#include "yas_audio_interruptor.h"
#include "yas_audio_ios_device_session.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct ios_session : ios_device_session, interruptor {
    enum category {
        ambient,
        solo_ambient,
        playback,
        record,
        play_and_record,
        multi_route,
    };

    using activate_result_t = result<std::nullptr_t, std::string>;

    [[nodiscard]] double sample_rate() const override;

    void set_preferred_sample_rate(double const);
    void set_preferred_io_buffer_frames(uint32_t const);

    [[nodiscard]] uint32_t output_channel_count() const override;
    [[nodiscard]] uint32_t input_channel_count() const override;
    [[nodiscard]] bool is_input_available() const;

    [[nodiscard]] bool is_active() const;
    [[nodiscard]] activate_result_t activate();
    [[nodiscard]] activate_result_t reactivate();
    void deactivate();

    bool is_interrupting() const override;

    [[nodiscard]] enum category category() const;
    void set_category(enum category const);

    [[nodiscard]] chaining::chain_unsync_t<device_method> device_chain() const override;
    [[nodiscard]] chaining::chain_unsync_t<interruption_method> interruption_chain() const override;

    [[nodiscard]] static ios_session_ptr const &shared();

   private:
    class impl;

    bool _is_active = false;
    bool _is_interrupting = false;
    enum category _category;
    double _preferred_sample_rate = 44100.0;
    uint32_t _preferred_io_buffer_frames = 1024;

    std::unique_ptr<impl> _impl;
    chaining::notifier_ptr<device_method> _device_notifier;
    chaining::notifier_ptr<interruption_method> _interruption_notifier;

    ios_session();

    activate_result_t _set_category();
    activate_result_t _apply_sample_rate();
    activate_result_t _apply_io_buffer_duration();
    activate_result_t _set_active();

    void _set_interrupting_and_notify(bool const);
    void _setup_interrupting();
    void _dispose_interrupting();
};
}  // namespace yas::audio

namespace yas::audio {
[[nodiscard]] bool is_output_category(enum audio::ios_session::category const);
[[nodiscard]] bool is_input_category(enum audio::ios_session::category const);
}  // namespace yas::audio

#endif
