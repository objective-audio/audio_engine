//
//  yas_audio_unit_io_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct unit_io_node::impl : unit_node::impl {
        impl();
        virtual ~impl();

        void prepare(audio::unit_io_node &node);

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_device(audio::device const &device);
        audio::device device() const;
#endif
        double device_sample_rate() const;
        uint32_t output_device_channel_count() const;
        uint32_t input_device_channel_count() const;

        void set_channel_map(channel_map_t const &, audio::direction const);
        channel_map_t const &channel_map(audio::direction const) const;

        virtual void prepare_audio_unit() override;

        audio::unit_io_node::subject_t &subject();

       private:
        class core;
        std::unique_ptr<core> _core;

        void update_unit_io_connections();
    };

    struct unit_output_node::impl : unit_io_node::impl {
        impl();

        virtual void prepare_audio_unit() override;
    };

    struct unit_input_node::impl : unit_io_node::impl {
        impl();
        virtual ~impl();

        void prepare(audio::unit_input_node const &);

        void update_unit_input_connections();
        virtual void prepare_audio_unit() override;

       private:
        class core;
        std::unique_ptr<core> _core;
    };
}
}
