//
//  yas_audio_mac_io_core.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_io_core.h"

namespace yas::audio {
class mac_io_core_render_context;

struct mac_io_core final : io_core {
    ~mac_io_core();

    void initialize() override;
    void uninitialize() override;

    void set_render_handler(std::optional<io_render_f>) override;
    void set_maximum_frames_per_slice(uint32_t const) override;

    bool start() override;
    void stop() override;

    [[nodiscard]] pcm_buffer const *input_buffer_on_render() const override;
    [[nodiscard]] time const *input_time_on_render() const override;

    [[nodiscard]] static mac_io_core_ptr make_shared(mac_device_ptr const &);

   private:
    mac_device_ptr _device;
    std::optional<AudioDeviceIOProcID> _io_proc_id = std::nullopt;
    std::optional<chaining::any_observer_ptr> _device_system_observer = std::nullopt;
    std::optional<chaining::any_observer_ptr> _device_observer = std::nullopt;

    std::shared_ptr<mac_io_core_render_context> _render_context;
    std::optional<io_render_f> _render_handler = std::nullopt;
    uint32_t _maximum_frames = 4096;

    mac_io_core(mac_device_ptr const &);

    void _update_kernel();
    void _clear_kernel();
    bool _is_initialized() const;
};
}  // namespace yas::audio

#endif
