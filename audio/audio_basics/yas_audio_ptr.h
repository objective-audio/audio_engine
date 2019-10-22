//
//  yas_audio_ptr.h
//

#pragma once

#include <memory>

namespace yas::audio {
class graph;
class unit;
class pcm_buffer;
class time;
class file;
class io_kernel;
class io;
class avf_device;
class avf_io_core;
class device_io;
class mac_io_core;
class mac_device;
class io_device;

using graph_ptr = std::shared_ptr<graph>;
using unit_ptr = std::shared_ptr<unit>;
using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
using time_ptr = std::shared_ptr<time>;
using file_ptr = std::shared_ptr<file>;
using io_kernel_ptr = std::shared_ptr<io_kernel>;
using io_ptr = std::shared_ptr<io>;
using avf_device_ptr = std::shared_ptr<avf_device>;
using avf_io_core_ptr = std::shared_ptr<avf_io_core>;
using device_io_ptr = std::shared_ptr<device_io>;
using mac_io_core_ptr = std::shared_ptr<mac_io_core>;
using mac_device_ptr = std::shared_ptr<mac_device>;
using io_device_ptr = std::shared_ptr<io_device>;
}  // namespace yas::audio
