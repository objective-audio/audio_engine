//
//  envelope_module.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/common/ptr.h>

#include <map>
#include <ostream>

namespace yas::proc {
/// エンベロープを生成するモジュール
namespace envelope {
    template <typename T>
    using anchors_t = std::map<frame_index_t, T>;

    enum class output : connector_index_t {
        value,
    };

    template <typename T>
    [[nodiscard]] module_ptr make_signal_module(anchors_t<T>, frame_index_t const module_offset);
}  // namespace envelope
}  // namespace yas::proc

namespace yas {
void connect(proc::module_ptr const &, proc::envelope::output const &, proc::channel_index_t const &);

[[nodiscard]] std::string to_string(proc::envelope::output const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::proc::envelope::output const &);
