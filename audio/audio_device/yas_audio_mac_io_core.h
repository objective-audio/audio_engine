//
//  yas_audio_mac_io_core.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_format.h"
#include "yas_audio_io_core.h"
#include "yas_audio_mac_device.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct mac_io_core final : io_core {
    ~mac_io_core();

    void initialize() override;
    void uninitialize() override;

    void set_render_handler(std::optional<io_render_f>) override;
    void set_maximum_frames_per_slice(uint32_t const) override;

    bool start() override;
    void stop() override;

    [[nodiscard]] std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const override;
    [[nodiscard]] std::optional<time_ptr> const &input_time_on_render() const override;

    static mac_io_core_ptr make_shared(mac_device_ptr const &);

   private:
    std::weak_ptr<mac_io_core> _weak_io_core;
    mac_device_ptr _device;
    std::optional<AudioDeviceIOProcID> _io_proc_id = std::nullopt;
    std::optional<chaining::any_observer_ptr> _device_system_observer = std::nullopt;
    std::optional<chaining::any_observer_ptr> _device_observer = std::nullopt;

    std::optional<pcm_buffer_ptr> _input_buffer_on_render = std::nullopt;
    std::optional<time_ptr> _input_time_on_render = std::nullopt;

    mutable std::recursive_mutex _mutex;
    std::optional<io_render_f> __render_handler = std::nullopt;
    uint32_t __maximum_frames = 4096;
    std::optional<io_kernel_ptr> __kernel = std::nullopt;

    mac_io_core(mac_device_ptr const &);

    void _prepare(mac_io_core_ptr const &shared);

    std::optional<io_render_f> _render_handler() const;
    void _set_kernel(std::optional<io_kernel_ptr> const &);
    std::optional<io_kernel_ptr> _kernel() const;
    void _update_kernel();
};
}  // namespace yas::audio

#endif
