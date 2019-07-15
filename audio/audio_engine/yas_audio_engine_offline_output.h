//
//  yas_audio_engine_offline_output.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include <ostream>
#include "yas_audio_engine_offline_output_protocol.h"

namespace yas::audio::engine {
class node;

class offline_output final : public base {
   public:
    class impl;

    offline_output();
    offline_output(std::nullptr_t);

    virtual ~offline_output();

    bool is_running() const;

    audio::engine::node const &node() const;
    audio::engine::node &node();

    manageable_offline_output &manageable();

   private:
    offline_output(std::shared_ptr<impl> const &);

    manageable_offline_output _manageable = nullptr;
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::offline_start_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::offline_start_error_t const &);
