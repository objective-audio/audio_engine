//
//  math2_modules.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

#include <ostream>

namespace yas::proc {
/// パラメータを2つ受け取る算術関数の結果を生成するモジュール
namespace math2 {
    enum class kind {
        plus,
        minus,
        multiply,
        divide,

        atan2,

        pow,
        hypot,
    };

    enum class output : connector_index_t {
        result,
    };

    enum class input : connector_index_t {
        left,
        right,
    };
}  // namespace math2

template <typename T>
[[nodiscard]] module_ptr make_signal_module(math2::kind const);

template <typename T>
[[nodiscard]] module_ptr make_number_module(math2::kind const);
}  // namespace yas::proc

namespace yas {
void connect(proc::module_ptr const &, proc::math2::input const &, proc::channel_index_t const &);
void connect(proc::module_ptr const &, proc::math2::output const &, proc::channel_index_t const &);

[[nodiscard]] std::string to_string(proc::math2::kind const &);
[[nodiscard]] std::string to_string(proc::math2::input const &);
[[nodiscard]] std::string to_string(proc::math2::output const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::proc::math2::kind const &);
std::ostream &operator<<(std::ostream &, yas::proc::math2::input const &);
std::ostream &operator<<(std::ostream &, yas::proc::math2::output const &);
