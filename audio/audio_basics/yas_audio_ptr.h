//
//  yas_audio_ptr.h
//

#pragma once

#include <memory>

namespace yas::audio {
class pcm_buffer;
class time;
class file;
class io_kernel;
class io;
class avf_device;
class avf_io_core;
class mac_io_core;
class mac_device;
class io_device;
class avf_au;
class avf_au_parameter;
class avf_au_parameter_core;

using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
using time_ptr = std::shared_ptr<time>;
using file_ptr = std::shared_ptr<file>;
using io_kernel_ptr = std::shared_ptr<io_kernel>;
using io_ptr = std::shared_ptr<io>;
using avf_device_ptr = std::shared_ptr<avf_device>;
using avf_io_core_ptr = std::shared_ptr<avf_io_core>;
using mac_io_core_ptr = std::shared_ptr<mac_io_core>;
using mac_device_ptr = std::shared_ptr<mac_device>;
using io_device_ptr = std::shared_ptr<io_device>;
using avf_au_ptr = std::shared_ptr<avf_au>;
using avf_au_parameter_ptr = std::shared_ptr<avf_au_parameter>;
using avf_au_parameter_core_ptr = std::shared_ptr<avf_au_parameter_core>;
}  // namespace yas::audio
