//
//  yas_audio_engine_offline_output.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <cpp_utils/yas_task.h>
#include <ostream>
#include "yas_audio_engine_offline_output_protocol.h"

namespace yas::audio::engine {
class node;

struct offline_output : manageable_offline_output, std::enable_shared_from_this<offline_output> {
    bool is_running() const;

    audio::engine::node const &node() const;
    audio::engine::node &node();

    std::shared_ptr<manageable_offline_output> manageable();

   protected:
    offline_output();

    void prepare();

   private:
    task_queue _queue = nullptr;
    std::shared_ptr<audio::engine::node> _node;
    chaining::any_observer_ptr _reset_observer = nullptr;
    struct core;
    std::unique_ptr<core> _core;

    offline_output(offline_output const &) = delete;
    offline_output(offline_output &&) = delete;
    offline_output &operator=(offline_output const &) = delete;
    offline_output &operator=(offline_output &&) = delete;

    offline_start_result_t start(offline_render_f &&, offline_completion_f &&) override;
    void stop() override;
};

std::shared_ptr<offline_output> make_offline_output();
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::offline_start_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::offline_start_error_t const &);
