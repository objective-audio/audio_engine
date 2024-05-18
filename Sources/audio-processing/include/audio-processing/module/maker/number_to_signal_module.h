//
//  number_to_signal_module.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

#include <ostream>

namespace yas::proc {
/// 数値からシグナルへ変換するモジュール
namespace number_to_signal {
    enum class output : connector_index_t {
        signal,
    };

    enum class input : connector_index_t {
        number,
    };
}  // namespace number_to_signal

template <typename T>
[[nodiscard]] module_ptr make_number_to_signal_module();
}  // namespace yas::proc

namespace yas {
void connect(proc::module_ptr const &, proc::number_to_signal::input const &, proc::channel_index_t const &);
void connect(proc::module_ptr const &, proc::number_to_signal::output const &, proc::channel_index_t const &);

[[nodiscard]] std::string to_string(proc::number_to_signal::input const &);
[[nodiscard]] std::string to_string(proc::number_to_signal::output const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::proc::number_to_signal::input const &);
std::ostream &operator<<(std::ostream &, yas::proc::number_to_signal::output const &);
