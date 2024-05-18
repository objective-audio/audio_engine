//
//  cast_module.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

#include <ostream>
#include <string>

namespace yas::proc {
/// 型を変換するモジュール
namespace cast {
    enum class output : connector_index_t {
        value,
    };

    enum class input : connector_index_t {
        value,
    };

    template <typename In, typename Out>
    [[nodiscard]] module_ptr make_signal_module();

    template <typename In, typename Out>
    [[nodiscard]] module_ptr make_number_module();
}  // namespace cast
}  // namespace yas::proc

namespace yas {
void connect(proc::module_ptr const &, proc::cast::input const &, proc::channel_index_t const &);
void connect(proc::module_ptr const &, proc::cast::output const &, proc::channel_index_t const &);

std::string to_string(proc::cast::input const &);
std::string to_string(proc::cast::output const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::proc::cast::input const &);
std::ostream &operator<<(std::ostream &, yas::proc::cast::output const &);

#include "cast_module_private.h"
