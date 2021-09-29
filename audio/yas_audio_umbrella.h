//
//  yas_audio_umbrella.h
//

#pragma once

#include <audio/yas_audio_debug.h>
#include <audio/yas_audio_each_data.h>
#include <audio/yas_audio_exception.h>
#include <audio/yas_audio_file.h>
#include <audio/yas_audio_file_utils.h>
#include <audio/yas_audio_format.h>
#include <audio/yas_audio_io.h>
#include <audio/yas_audio_math.h>
#include <audio/yas_audio_offline_device.h>
#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_renewable_device.h>
#include <audio/yas_audio_time.h>
#include <audio/yas_audio_types.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_exception.h>
#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>

#if TARGET_OS_IPHONE

#include <audio/yas_audio_ios_device.h>

#elif TARGET_OS_MAC

#include <audio/yas_audio_graph_io.h>
#include <audio/yas_audio_graph_route.h>
#include <audio/yas_audio_mac_device.h>
#include <audio/yas_audio_mac_device_stream.h>

#endif

#include <audio/yas_audio_avf_au.h>
#include <audio/yas_audio_avf_au_parameter.h>
#include <audio/yas_audio_graph.h>
#include <audio/yas_audio_graph_avf_au.h>
#include <audio/yas_audio_graph_avf_au_mixer.h>
#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_io.h>
#include <audio/yas_audio_graph_node.h>
#include <audio/yas_audio_graph_route.h>
#include <audio/yas_audio_graph_tap.h>
#include <audio/yas_audio_rendering_graph.h>
