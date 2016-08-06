//
//  yas_audio_unit_io_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct unit_io_node::impl : base::impl {
        impl();
        impl(args &&);
        virtual ~impl();

        void prepare(audio::unit_io_node &node);

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(audio::device const &device);
        audio::device device();
#endif
        double device_sample_rate();
        uint32_t output_device_channel_count();
        uint32_t input_device_channel_count();

        void set_channel_map(channel_map_t const &, audio::direction const);
        channel_map_t const &channel_map(audio::direction const);

        audio::unit_io_node::subject_t &subject();

        audio::unit_node &unit_node();

       private:
        class core;
        std::unique_ptr<core> _core;

        void update_unit_io_connections();
    };

    struct unit_output_node::impl : base::impl {
        impl();

        audio::unit_io_node _unit_io_node;
    };

    struct unit_input_node::impl : base::impl {
        impl();
        virtual ~impl();

        void prepare(audio::unit_input_node const &);

        void update_unit_input_connections();

        audio::unit_io_node _unit_io_node;

       private:
        class core;
        std::unique_ptr<core> _core;
    };
}
}
