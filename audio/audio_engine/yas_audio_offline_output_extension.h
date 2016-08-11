//
//  yas_audio_offline_output_extension.h
//

#pragma once

#include "yas_audio_offline_output_extension_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class node;

    class offline_output_extension : public base {
       public:
        class impl;

        offline_output_extension();
        offline_output_extension(std::nullptr_t);

        virtual ~offline_output_extension() final;

        bool is_running() const;

        audio::node const &node() const;
        audio::node &node();

        manageable_offline_output_unit &manageable();

       private:
        offline_output_extension(std::shared_ptr<impl> const &);

        manageable_offline_output_unit _manageable = nullptr;
    };
}

std::string to_string(audio::offline_start_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::offline_start_error_t const &);
