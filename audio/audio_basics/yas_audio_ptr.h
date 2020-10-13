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
class ios_device;
class ios_io_core;
class ios_device_session;
class ios_session;
class interruptor;
class mac_io_core;
class mac_device;
class mac_empty_device;
class io_device;
class renewable_device;
class avf_au;
class avf_au_parameter;
class avf_au_parameter_core;
class offline_device;
class offline_io_core;
class graph_connection;
class graph_kernel;
class graph;
class graph_node;
class graph_route;
class graph_tap;
class graph_input_tap;
class graph_io;
class graph_avf_au;
class graph_avf_au_mixer;

class manageable_graph_au;
class graph_node_removable;
class manageable_graph_kernel;
class manageable_graph_io;
class connectable_graph_node;
class manageable_graph_node;
class renderable_graph_node;
class manageable_graph_avf_au;
class renderable_graph_connection;

using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
using time_ptr = std::shared_ptr<time>;
using file_ptr = std::shared_ptr<file>;
using io_kernel_ptr = std::shared_ptr<io_kernel>;
using io_ptr = std::shared_ptr<io>;
using ios_device_session_ptr = std::shared_ptr<ios_device_session>;
using ios_device_ptr = std::shared_ptr<ios_device>;
using ios_io_core_ptr = std::shared_ptr<ios_io_core>;
using ios_session_ptr = std::shared_ptr<ios_session>;
using interruptor_ptr = std::shared_ptr<interruptor>;
using mac_io_core_ptr = std::shared_ptr<mac_io_core>;
using mac_device_ptr = std::shared_ptr<mac_device>;
using mac_empty_device_ptr = std::shared_ptr<mac_empty_device>;
using io_device_ptr = std::shared_ptr<io_device>;
using renewable_device_ptr = std::shared_ptr<renewable_device>;
using avf_au_ptr = std::shared_ptr<avf_au>;
using avf_au_parameter_ptr = std::shared_ptr<avf_au_parameter>;
using avf_au_parameter_core_ptr = std::shared_ptr<avf_au_parameter_core>;
using offline_device_ptr = std::shared_ptr<offline_device>;
using offline_io_core_ptr = std::shared_ptr<offline_io_core>;
using graph_connection_ptr = std::shared_ptr<graph_connection>;
using graph_kernel_ptr = std::shared_ptr<graph_kernel>;
using graph_ptr = std::shared_ptr<graph>;
using graph_wptr = std::weak_ptr<graph>;
using graph_node_ptr = std::shared_ptr<graph_node>;
using graph_route_ptr = std::shared_ptr<graph_route>;
using graph_tap_ptr = std::shared_ptr<graph_tap>;
using graph_input_tap_ptr = std::shared_ptr<graph_input_tap>;
using graph_io_ptr = std::shared_ptr<graph_io>;
using graph_avf_au_ptr = std::shared_ptr<graph_avf_au>;
using graph_avf_au_mixer_ptr = std::shared_ptr<graph_avf_au_mixer>;

using manageable_graph_au_ptr = std::shared_ptr<manageable_graph_au>;
using graph_node_removable_ptr = std::shared_ptr<graph_node_removable>;
using manageable_graph_kernel_ptr = std::shared_ptr<manageable_graph_kernel>;
using manageable_graph_io_ptr = std::shared_ptr<manageable_graph_io>;
using connectable_graph_node_ptr = std::shared_ptr<connectable_graph_node>;
using manageable_graph_node_ptr = std::shared_ptr<manageable_graph_node>;
using renderable_graph_node_ptr = std::shared_ptr<renderable_graph_node>;
using manageable_graph_avf_au_ptr = std::shared_ptr<manageable_graph_avf_au>;
using renderable_graph_node_ptr = std::shared_ptr<renderable_graph_node>;
using renderable_graph_connection_ptr = std::shared_ptr<renderable_graph_connection>;
}  // namespace yas::audio
