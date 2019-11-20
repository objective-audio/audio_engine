//
//  yas_audio_engine_ptr.h
//

#pragma once

#include "yas_audio_ptr.h"

namespace yas::audio::engine {
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
class io;
class avf_au;
class avf_au_mixer;

class manageable_au;
class node_removable;
class manageable_kernel;
class manageable_io;
class connectable_node;
class manageable_node;
class manageable_avf_au;

using au_output_ptr = std::shared_ptr<au_output>;
using au_input_ptr = std::shared_ptr<au_input>;
using au_mixer_ptr = std::shared_ptr<au_mixer>;
using au_ptr = std::shared_ptr<au>;
using connection_ptr = std::shared_ptr<connection>;
using kernel_ptr = std::shared_ptr<kernel>;
using manager_ptr = std::shared_ptr<manager>;
using manager_wptr = std::weak_ptr<manager>;
using node_ptr = std::shared_ptr<node>;
using offline_output_ptr = std::shared_ptr<offline_output>;
using route_ptr = std::shared_ptr<route>;
using tap_ptr = std::shared_ptr<tap>;
using io_ptr = std::shared_ptr<engine::io>;
using avf_au_ptr = std::shared_ptr<engine::avf_au>;
using avf_au_mixer_ptr = std::shared_ptr<engine::avf_au_mixer>;

using manageable_au_ptr = std::shared_ptr<manageable_au>;
using node_removable_ptr = std::shared_ptr<node_removable>;
using manageable_kernel_ptr = std::shared_ptr<manageable_kernel>;
using manageable_io_ptr = std::shared_ptr<manageable_io>;
using connectable_node_ptr = std::shared_ptr<connectable_node>;
using manageable_node_ptr = std::shared_ptr<manageable_node>;
using manageable_avf_au_ptr = std::shared_ptr<manageable_avf_au>;
}  // namespace yas::audio::engine
