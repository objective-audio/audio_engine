//
//  yas_audio_unit_io_extension.h
//

#pragma once

#include "yas_audio_types.h"
#include "yas_base.h"
#include "yas_observing.h"

namespace yas {
namespace audio {
    class unit_extension;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    class device;
#endif
    class unit_io_extension : public base {
       public:
        class impl;

        enum class method {
            did_update_connection,
        };

        using subject_t = yas::subject<unit_io_extension, method>;
        using observer_t = yas::observer<unit_io_extension, method>;

        struct args {
            bool enable_input = true;
            bool enable_output = true;
        };

        unit_io_extension();
        unit_io_extension(args);
        unit_io_extension(std::nullptr_t);

        virtual ~unit_io_extension() final;

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

        audio::unit_extension const &unit_extension() const;
        audio::unit_extension &unit_extension();
    };

    class unit_output_extension : public base {
       public:
        class impl;

        unit_output_extension();
        unit_output_extension(std::nullptr_t);

        virtual ~unit_output_extension() final;

        void set_channel_map(channel_map_t const &);
        channel_map_t const &channel_map() const;

        audio::unit_io_extension const &unit_io_extension() const;
        audio::unit_io_extension &unit_io_extension();
    };

    class unit_input_extension : public base {
       public:
        class impl;

        unit_input_extension();
        unit_input_extension(std::nullptr_t);

        virtual ~unit_input_extension() final;

        void set_channel_map(channel_map_t const &);
        channel_map_t const &channel_map() const;

        audio::unit_io_extension const &unit_io_extension() const;
        audio::unit_io_extension &unit_io_extension();
    };
}
}
