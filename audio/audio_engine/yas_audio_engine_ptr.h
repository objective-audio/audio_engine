//
//  yas_audio_engine_ptr.h
//

#pragma once

#include "yas_audio_ptr.h"

namespace yas::audio::engine {
class au_io;
class au_output;
class au_input;
class au_mixer;
class au;
class connection;
class kernel;
class manager;
class node;
class offline_output;
class route;
class tap;

using au_io_ptr = std::shared_ptr<au_io>;
using au_output_ptr = std::shared_ptr<au_output>;
using au_input_ptr = std::shared_ptr<au_input>;
using au_mixer_ptr = std::shared_ptr<au_mixer>;
using au_ptr = std::shared_ptr<au>;
using connection_ptr = std::shared_ptr<connection>;
using kernel_ptr = std::shared_ptr<kernel>;
using manager_ptr = std::shared_ptr<manager>;
using node_ptr = std::shared_ptr<node>;
using offline_output_ptr = std::shared_ptr<offline_output>;
using route_ptr = std::shared_ptr<route>;
using tap_ptr = std::shared_ptr<tap>;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
class device_io;

using device_io_ptr = std::shared_ptr<engine::device_io>;
#endif
}  // namespace yas::audio::engine
