//
//  yas_audio_unit_io_node.h
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit_node.h"

namespace yas {
namespace audio {
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class device;
#endif
    class unit_io_node : public unit_node {
       public:
        enum class method {
            did_update_connection,
        };

        using subject_t = yas::subject<unit_io_node, method>;
        using observer_t = yas::observer<unit_io_node, method>;

        unit_io_node();
        unit_io_node(std::nullptr_t);

        virtual ~unit_io_node();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(audio::device const &);
        audio::device device() const;
#endif

        void set_channel_map(channel_map_t const &, audio::direction const);
        channel_map_t const &channel_map(audio::direction const) const;

        double device_sample_rate() const;
        uint32_t output_device_channel_count() const;
        uint32_t input_device_channel_count() const;

        subject_t &subject();

       protected:
        class impl;

        unit_io_node(std::shared_ptr<impl> const &, AudioComponentDescription const &);
    };

    class unit_output_node : public unit_io_node {
       public:
        class impl;

        unit_output_node();
        unit_output_node(std::nullptr_t);

        void set_channel_map(channel_map_t const &);
        channel_map_t const &channel_map() const;
    };

    class unit_input_node : public unit_io_node {
       public:
        class impl;

        unit_input_node();
        unit_input_node(std::nullptr_t);

        void set_channel_map(channel_map_t const &);
        channel_map_t const &channel_map() const;
    };
}
}

#include "yas_audio_unit_io_node_impl.h"
