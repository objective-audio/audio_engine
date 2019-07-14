//
//  yas_audio_engine_device_io.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_device_io_protocol.h"

namespace yas::audio {
class device;
}

namespace yas::audio::engine {
class node;

struct device_io final : base, manageable_device_io {
    class impl;

    device_io();
    device_io(std::nullptr_t);
    explicit device_io(std::shared_ptr<audio::device> const &device);

    virtual ~device_io();

    void set_device(std::shared_ptr<audio::device> const &device);
    std::shared_ptr<audio::device> device() const;

    std::shared_ptr<audio::engine::node> const &node() const;
    std::shared_ptr<audio::engine::node> &node();

    void add_raw_device_io() override;
    void remove_raw_device_io() override;
    std::shared_ptr<audio::device_io> &raw_device_io() override;
};
}  // namespace yas::audio::engine

#endif
