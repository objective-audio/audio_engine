//
//  yas_audio_engine_offline_output.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <cpp_utils/yas_task.h>
#include <ostream>
#include "yas_audio_engine_offline_output_protocol.h"
#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
struct offline_output : manageable_offline_output, std::enable_shared_from_this<offline_output> {
    virtual ~offline_output();

    bool is_running() const;

    audio::engine::node_ptr const &node() const;

    manageable_offline_output_ptr manageable();

   private:
    std::optional<task_queue> _queue = std::nullopt;
    node_ptr _node;
    chaining::any_observer_ptr _reset_observer = nullptr;
    struct core;
    std::unique_ptr<core> _core;

    offline_output();

    void _prepare();

    offline_output(offline_output const &) = delete;
    offline_output(offline_output &&) = delete;
    offline_output &operator=(offline_output const &) = delete;
    offline_output &operator=(offline_output &&) = delete;

    offline_start_result_t start(offline_render_f &&, offline_completion_f &&) override;
    void stop() override;

   public:
    static offline_output_ptr make_shared();
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::offline_start_error_t const &error);
}

std::ostream &operator<<(std::ostream &, yas::audio::engine::offline_start_error_t const &);
