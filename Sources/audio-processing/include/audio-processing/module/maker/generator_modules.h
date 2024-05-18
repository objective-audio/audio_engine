//
//  generator_modules.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

#include <ostream>

namespace yas::proc {
/// 単純な生成モジュール
namespace generator {
    enum class kind {
        second,  /// 1秒につき1.0増えるシグナルを生成する
        frame,
    };

    enum class output : connector_index_t {
        value,
    };
}  // namespace generator

// frame_offsetは絶対的な時間の位置を足してずらす
template <typename T>
[[nodiscard]] module_ptr make_signal_module(generator::kind const, frame_index_t const frame_offset);
}  // namespace yas::proc

namespace yas {
void connect(proc::module_ptr const &, proc::generator::output const &, proc::channel_index_t const &);

[[nodiscard]] std::string to_string(proc::generator::output const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::proc::generator::output const &);
