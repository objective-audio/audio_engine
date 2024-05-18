//
//  constant_module.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

namespace yas::proc {
/// 固定値を生成するモジュール
namespace constant {
    enum class output : connector_index_t {
        value,
    };
}

template <typename T>
[[nodiscard]] module_ptr make_signal_module(T);

template <typename T>
[[nodiscard]] module_ptr make_number_module(T);
}  // namespace yas::proc
