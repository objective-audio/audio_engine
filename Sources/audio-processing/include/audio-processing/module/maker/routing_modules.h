//
//  routing_module.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

#include <ostream>

namespace yas::proc {
/// ルーティングするモジュール
namespace routing {
    enum class kind {
        move,
        copy,
    };

    enum class input : connector_index_t {
        value,
    };

    enum class output : connector_index_t {
        value,
    };
}  // namespace routing

template <typename T>
[[nodiscard]] module_ptr make_signal_module(routing::kind const);

template <typename T>
[[nodiscard]] module_ptr make_number_module(routing::kind const);
}  // namespace yas::proc

namespace yas {
void connect(proc::module_ptr const &, proc::routing::input const &, proc::channel_index_t const &);
void connect(proc::module_ptr const &, proc::routing::output const &, proc::channel_index_t const &);

[[nodiscard]] std::string to_string(proc::routing::input const &);
[[nodiscard]] std::string to_string(proc::routing::output const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::proc::routing::input const &);
std::ostream &operator<<(std::ostream &, yas::proc::routing::output const &);
