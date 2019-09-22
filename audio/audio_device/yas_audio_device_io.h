//
//  yas_audio_device_io.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <chaining/yas_chaining_umbrella.h>
#include <functional>
#include "yas_audio_engine_ptr.h"
#include "yas_audio_time.h"
#include "yas_audio_types.h"

namespace yas::audio {
struct device_io final {
    struct render_args {
        audio::pcm_buffer_ptr const &output_buffer;
        std::optional<audio::time> const when;
    };

    using render_f = std::function<void(render_args)>;

    ~device_io();

    void set_device(audio::device_ptr const device);
    audio::device_ptr const &device() const;
    bool is_running() const;
    void set_render_handler(render_f);
    void set_maximum_frames_per_slice(uint32_t const frames);
    uint32_t maximum_frames_per_slice() const;

    void start();
    void stop();

    pcm_buffer_ptr const &input_buffer_on_render() const;
    audio::time_ptr const &input_time_on_render() const;

   private:
    class kernel;
    using kernel_ptr = std::shared_ptr<kernel>;

    std::weak_ptr<device_io> _weak_device_io;
    audio::device_ptr _device = nullptr;
    bool _is_running = false;
    AudioDeviceIOProcID _io_proc_id = nullptr;
    pcm_buffer_ptr _input_buffer_on_render = nullptr;
    audio::time_ptr _input_time_on_render = nullptr;
    chaining::any_observer_ptr _device_system_observer = nullptr;
    std::unordered_map<std::uintptr_t, chaining::any_observer_ptr> _device_observers;

    device_io();

    void _prepare(device_io_ptr const &, device_ptr const &);
    void _initialize();
    void _uninitialize();

    mutable std::recursive_mutex _mutex;
    render_f __render_handler = nullptr;
    uint32_t __maximum_frames = 4096;
    device_io::kernel_ptr __kernel = nullptr;

    void _set_render_handler(render_f &&handler);
    render_f _render_handler() const;
    void _set_maximum_frames(uint32_t const frames);
    uint32_t _maximum_frames() const;
    void _set_kernel(device_io::kernel_ptr const &kernel);
    device_io::kernel_ptr _kernel() const;
    void _update_kernel();

   public:
    static audio::device_io_ptr make_shared(audio::device_ptr const &);
};

}  // namespace yas::audio

#endif
