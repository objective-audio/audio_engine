//
//  yas_audio_unit_io_node.h
//

#pragma once

#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_observing.h"

namespace yas {
namespace audio {
    namespace engine {
        class unit_node;
    }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class device;
#endif
    class unit_io_node : public base {
       public:
        class impl;

        enum class method {
            did_update_connection,
        };

        using subject_t = yas::subject<unit_io_node, method>;
        using observer_t = yas::observer<unit_io_node, method>;

        struct args {
            bool enable_input = true;
            bool enable_output = true;
        };

        unit_io_node();
        unit_io_node(args);
        unit_io_node(std::nullptr_t);

        virtual ~unit_io_node() final;

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

        audio::engine::unit_node const &unit_node() const;
        audio::engine::unit_node &unit_node();
    };

    class unit_output_node : public base {
       public:
        class impl;

        unit_output_node();
        unit_output_node(std::nullptr_t);

        virtual ~unit_output_node() final;

        void set_channel_map(channel_map_t const &);
        channel_map_t const &channel_map() const;

        audio::unit_io_node const &unit_io_node() const;
        audio::unit_io_node &unit_io_node();
    };

    class unit_input_node : public base {
       public:
        class impl;

        unit_input_node();
        unit_input_node(std::nullptr_t);

        virtual ~unit_input_node() final;

        void set_channel_map(channel_map_t const &);
        channel_map_t const &channel_map() const;

        audio::unit_io_node const &unit_io_node() const;
        audio::unit_io_node &unit_io_node();
    };
}
}
