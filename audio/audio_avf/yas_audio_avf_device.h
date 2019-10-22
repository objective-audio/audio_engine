//
//  yas_audio_avf_device.h
//

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE

#include "yas_audio_avf_io_core.h"
#include "yas_audio_format.h"
#include "yas_audio_io_device.h"
#include "yas_audio_ptr.h"

namespace yas::audio {
struct avf_device final : io_device {
    double sample_rate() const;

    uint32_t input_channel_count() const override;
    uint32_t output_channel_count() const override;

    std::optional<audio::format> input_format() const override;
    std::optional<audio::format> output_format() const override;

    io_core_ptr make_io_core() const override;

    static avf_device_ptr make_shared();

   private:
    std::weak_ptr<avf_device> _weak_device;

    avf_device();
};
}  // namespace yas::audio

#endif
