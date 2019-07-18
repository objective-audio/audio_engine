//
//  yas_audio_engine_offline_output.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include <ostream>
#include "yas_audio_engine_offline_output_protocol.h"

namespace yas::audio::engine {
class node;

struct offline_output final : base, manageable_offline_output {
   public:
    class impl;

    offline_output();
    offline_output(std::nullptr_t);

    virtual ~offline_output();

    bool is_running() const;

    audio::engine::node const &node() const;
    audio::engine::node &node();

    offline_start_result_t start(offline_render_f &&, offline_completion_f &&) override;
    void stop() override;

   private:
    offline_output(std::shared_ptr<impl> const &);
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::offline_start_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::offline_start_error_t const &);
