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

struct device_io : manageable_device_io, std::enable_shared_from_this<device_io> {
    class impl;
    class core;

    device_io(device_io &&) = default;
    device_io &operator=(device_io &&) = default;

    virtual ~device_io();

    void set_device(std::shared_ptr<audio::device> const &device);
    std::shared_ptr<audio::device> device() const;

    audio::engine::node const &node() const;
    audio::engine::node &node();

#warning todo privateにしてmanageableでアクセスする
    void add_raw_device_io() override;
    void remove_raw_device_io() override;
    std::shared_ptr<audio::device_io> &raw_device_io() override;

   protected:
    device_io();

    void _prepare();

   private:
    std::shared_ptr<impl> _impl;

    device_io(device_io const &) = delete;
    device_io &operator=(device_io const &) = delete;
};

std::shared_ptr<device_io> make_device_io();
}  // namespace yas::audio::engine

#endif
