//
//  yas_audio_offline_output_node.h
//

#pragma once

#include "yas_audio_node.h"
#include "yas_audio_offline_output_node_protocol.h"

namespace yas {
namespace audio {
    class offline_output_node : public node {
       public:
        class impl;

        offline_output_node();
        offline_output_node(std::nullptr_t);

        ~offline_output_node();

        bool is_running() const;

        manageable_offline_output_unit &manageable();

       private:
        offline_output_node(std::shared_ptr<impl> const &);

        manageable_offline_output_unit _manageable = nullptr;
    };
}

std::string to_string(audio::offline_start_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::offline_start_error_t const &);

#include "yas_audio_offline_output_node_impl.h"
