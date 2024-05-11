//
//  umbrella.hpp
//

#pragma once

#include <audio-engine/common/time.h>
#include <audio-engine/common/types.h>
#include <audio-engine/file/file.h>
#include <audio-engine/file/file_utils.h>
#include <audio-engine/format/format.h>
#include <audio-engine/io/io.h>
#include <audio-engine/io/renewable_device.h>
#include <audio-engine/offline/offline_device.h>
#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-engine/utils/debug.h>
#include <audio-engine/utils/each_data.h>
#include <audio-engine/utils/exception.h>
#include <audio-engine/utils/math.h>
#include <cpp-utils/yas_cf_utils.h>
#include <cpp-utils/yas_exception.h>
#include <cpp-utils/yas_result.h>
#include <cpp-utils/yas_stl_utils.h>

#if TARGET_OS_IPHONE

#include <audio-engine/ios/ios_device.h>

#elif TARGET_OS_MAC

#include <audio-engine/graph/graph_io.h>
#include <audio-engine/graph/graph_route.h>
#include <audio-engine/mac/mac_device.h>
#include <audio-engine/mac/mac_device_stream.h>

#endif

#include <audio-engine/avf_au/avf_au.h>
#include <audio-engine/avf_au/avf_au_parameter.h>
#include <audio-engine/graph/graph.h>
#include <audio-engine/graph/graph_avf_au.h>
#include <audio-engine/graph/graph_avf_au_mixer.h>
#include <audio-engine/graph/graph_connection.h>
#include <audio-engine/graph/graph_io.h>
#include <audio-engine/graph/graph_node.h>
#include <audio-engine/graph/graph_route.h>
#include <audio-engine/graph/graph_tap.h>
#include <audio-engine/rendering/rendering_graph.h>
