//
//  yas_audio_types.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <memory>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <experimental/optional>
#include <AudioUnit/AUComponent.h>

namespace yas
{
    namespace audio
    {
        union render_id {
            void *v;
            struct {
                UInt8 graph;
                UInt16 unit;
            };
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

        struct render_parameters {
            render_type in_render_type;
            AudioUnitRenderActionFlags *io_action_flags;
            const AudioTimeStamp *io_time_stamp;
            UInt32 in_bus_number;
            UInt32 in_number_frames;
            AudioBufferList *io_data;
            render_id render_id;
        };

        using bus_result_t = std::experimental::optional<UInt32>;
        using abl_uptr = std::unique_ptr<AudioBufferList, std::function<void(AudioBufferList *)>>;
        using abl_data_uptr = std::unique_ptr<std::vector<std::vector<UInt8>>>;
        using channel_map_t = std::vector<UInt32>;
    }

    UInt32 to_uint32(const audio::direction &);
    std::string to_string(const audio::direction &);
    std::string to_string(const AudioUnitScope scope);
    std::string to_string(const audio::render_type &);
    std::string to_string(const OSStatus err);

    constexpr std::experimental::nullopt_t nullopt = std::experimental::nullopt;
}
