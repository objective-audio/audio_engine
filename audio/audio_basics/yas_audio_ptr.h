//
//  yas_audio_ptr.h
//

#pragma once

#include <TargetConditionals.h>
#include <memory>

namespace yas::audio {
class graph;
class unit;
class pcm_buffer;
class time;
class file;
class io_kernel;

using graph_ptr = std::shared_ptr<graph>;
using unit_ptr = std::shared_ptr<unit>;
using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
using time_ptr = std::shared_ptr<time>;
using file_ptr = std::shared_ptr<file>;
using io_kernel_ptr = std::shared_ptr<io_kernel>;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
class device_io;
class device;

using device_io_ptr = std::shared_ptr<device_io>;
using device_ptr = std::shared_ptr<device>;
#endif
}  // namespace yas::audio
