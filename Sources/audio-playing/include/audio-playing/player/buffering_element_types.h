//
//  buffering_element_types.h
//

#pragma once

#include <ostream>
#include <string>

namespace yas::playing {
enum class audio_buffering_element_state {
    /// 新規作成後の待機状態。初回の書き込み中もここ
    initial,
    /// ファイルからバッファに書き込み中
    writable,
    /// バッファにデータが準備され読み込み中
    readable,
};
}  // namespace yas::playing

namespace yas {
std::string to_string(playing::audio_buffering_element_state const &);
}

std::ostream &operator<<(std::ostream &, yas::playing::audio_buffering_element_state const &);
