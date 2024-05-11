//
//  yas_audio_engine_umbrella.hpp
//

#pragma once

#include <audio-engine/common/yas_audio_time.h>
#include <audio-engine/common/yas_audio_types.h>
#include <audio-engine/file/yas_audio_file.h>
#include <audio-engine/file/yas_audio_file_utils.h>
#include <audio-engine/format/yas_audio_format.h>
#include <audio-engine/io/yas_audio_io.h>
#include <audio-engine/io/yas_audio_renewable_device.h>
#include <audio-engine/offline/yas_audio_offline_device.h>
#include <audio-engine/pcm_buffer/yas_audio_pcm_buffer.h>
#include <audio-engine/utils/yas_audio_debug.h>
#include <audio-engine/utils/yas_audio_each_data.h>
#include <audio-engine/utils/yas_audio_exception.h>
#include <audio-engine/utils/yas_audio_math.h>
#include <cpp-utils/yas_cf_utils.h>
#include <cpp-utils/yas_exception.h>
#include <cpp-utils/yas_result.h>
#include <cpp-utils/yas_stl_utils.h>

#if TARGET_OS_IPHONE

#include <audio-engine/ios/yas_audio_ios_device.h>

#elif TARGET_OS_MAC

#include <audio-engine/graph/yas_audio_graph_io.h>
#include <audio-engine/graph/yas_audio_graph_route.h>
#include <audio-engine/mac/yas_audio_mac_device.h>
#include <audio-engine/mac/yas_audio_mac_device_stream.h>

#endif

#include <audio-engine/avf_au/yas_audio_avf_au.h>
#include <audio-engine/avf_au/yas_audio_avf_au_parameter.h>
#include <audio-engine/graph/yas_audio_graph.h>
#include <audio-engine/graph/yas_audio_graph_avf_au.h>
#include <audio-engine/graph/yas_audio_graph_avf_au_mixer.h>
#include <audio-engine/graph/yas_audio_graph_connection.h>
#include <audio-engine/graph/yas_audio_graph_io.h>
#include <audio-engine/graph/yas_audio_graph_node.h>
#include <audio-engine/graph/yas_audio_graph_route.h>
#include <audio-engine/graph/yas_audio_graph_tap.h>
#include <audio-engine/rendering/yas_audio_rendering_graph.h>
