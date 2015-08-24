//
//  yas_audio_types.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>
#include <string>
#include <vector>
#include <map>
#include <experimental/optional>
#include <AudioUnit/AUComponent.h>

namespace yas
{
    union render_id {
        void *v;
        struct {
            UInt8 graph;
            UInt16 unit;
        };
    };

    union flex_pointer {
        void *v;
        Float32 *f32;
        Float64 *f64;
        SInt32 *i32;
        UInt32 *u32;
        SInt16 *i16;
        UInt16 *u16;
        SInt8 *i8;
        UInt8 *u8;
    };

    enum class pcm_format : UInt32 {
        other = 0,
        float32,
        float64,
        int16,
        fixed824,
    };

    enum class render_type : UInt32 {
        normal = 0,
        input,
        notify,
        unknown,
    };

    enum class direction {
        output = 0,
        input = 1,
    };

    std::string to_string(const yas::direction &);

    struct render_parameters {
        render_type in_render_type;
        AudioUnitRenderActionFlags *io_action_flags;
        const AudioTimeStamp *io_time_stamp;
        UInt32 in_bus_number;
        UInt32 in_number_frames;
        AudioBufferList *io_data;
        render_id render_id;
    };

    using bus_result = std::experimental::optional<uint32_t>;

    class objc_strong_container;
    class objc_weak_container;
    class audio_time;
    class audio_format;
    class pcm_buffer;
    class audio_file_reader;
    class audio_file_writer;
    class channel_route;
    class audio_graph;
    class audio_unit;
    class audio_engine;
    class audio_node;
    class audio_connection;
    class audio_unit_node;
    class audio_unit_output_node;
    class audio_unit_input_node;
    class audio_offline_output_node;
    class audio_tap_node;
    class audio_input_tap_node;
    class audio_unit_mixer_node;

    using objc_strong_container_ptr = std::shared_ptr<objc_strong_container>;
    using objc_weak_container_ptr = std::shared_ptr<objc_weak_container>;
    using audio_time_ptr = std::shared_ptr<audio_time>;
    using audio_format_ptr = std::shared_ptr<audio_format>;
    using pcm_buffer_ptr = std::shared_ptr<pcm_buffer>;
    using abl_unique_ptr = std::unique_ptr<AudioBufferList, std::function<void(AudioBufferList *)>>;
    using abl_data_unique_ptr = std::unique_ptr<std::vector<std::vector<UInt8>>>;
    using audio_file_reader_ptr = std::shared_ptr<audio_file_reader>;
    using audio_file_writer_ptr = std::shared_ptr<audio_file_writer>;
    using channel_route_ptr = std::shared_ptr<channel_route>;
    using audio_graph_ptr = std::shared_ptr<audio_graph>;
    using audio_graph_weak_ptr = std::weak_ptr<audio_graph>;
    using audio_unit_ptr = std::shared_ptr<audio_unit>;
    using channel_map = std::vector<uint32_t>;
    using channel_map_uptr = std::unique_ptr<channel_map>;
    using audio_engine_ptr = std::shared_ptr<audio_engine>;
    using audio_node_ptr = std::shared_ptr<audio_node>;
    using audio_connection_ptr = std::shared_ptr<audio_connection>;
    using audio_connection_weak_ptr = std::weak_ptr<audio_connection>;
    using audio_connection_weak_map = std::map<uint32_t, audio_connection_weak_ptr>;
    using audio_connection_weak_map_ptr = std::shared_ptr<audio_connection_weak_map>;
    using audio_unit_node_ptr = std::shared_ptr<audio_unit_node>;
    using audio_unit_node_weak_ptr = std::weak_ptr<audio_unit_node>;
    using audio_unit_output_node_ptr = std::shared_ptr<audio_unit_output_node>;
    using audio_unit_input_node_ptr = std::shared_ptr<audio_unit_input_node>;
    using audio_offline_output_node_ptr = std::shared_ptr<audio_offline_output_node>;
    using audio_tap_node_ptr = std::shared_ptr<audio_tap_node>;
    using audio_input_tap_node_ptr = std::shared_ptr<audio_input_tap_node>;
    using audio_unit_mixer_node_ptr = std::shared_ptr<audio_unit_mixer_node>;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class audio_device_stream;
    class audio_device;
    class audio_device_io;
    class audio_device_io_node;

    using audio_device_stream_ptr = std::shared_ptr<audio_device_stream>;
    using audio_device_ptr = std::shared_ptr<audio_device>;
    using audio_device_io_ptr = std::shared_ptr<audio_device_io>;
    using audio_device_io_node_ptr = std::shared_ptr<audio_device_io_node>;
#endif
}
