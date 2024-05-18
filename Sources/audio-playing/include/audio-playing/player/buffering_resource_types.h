//
//  buffering_resource_types.h
//

#pragma once

#include <ostream>
#include <string>

namespace yas::playing {
enum class audio_buffering_setup_state {
    /// 新規生成後の待機状態
    /// render側: 無条件でcreatingにする
    /// task側: 何もしない
    initial,

    /// bufferを作る状態
    /// render側: 何もしない
    /// task側: bufferを作って終わったらrendering_stateをwaitingにし、renderingにする
    creating,

    /// bufferがある状態
    /// render側: 読み込みに使う。フォーマットが合わなければcreatingにする
    /// task側: 何もしない
    rendering,
};

enum class audio_buffering_rendering_state {
    /// 待機。初期状態
    /// render側: 無条件でall_writingにする。
    /// task側: 何もしない
    waiting,

    /// 全てのバッファに書き込む状態
    /// render側: 何もしない。
    /// task側: 全体を書き込み終わったらadvancingにする
    all_writing,

    /// 再生して進む状態。主に個別のバッファを扱う
    /// render側:
    /// seekされたりch_mappingが変更されたらall_writingにする。
    /// 読み込んでバッファの最後まで行ったら個別にwritableにする。
    /// task側:
    /// buffering的には何もしない
    /// 個別のバッファがwritableならファイルから読み込んで、終わったらreadableにする
    advancing,
};
}  // namespace yas::playing

namespace yas {
std::string to_string(playing::audio_buffering_setup_state const);
std::string to_string(playing::audio_buffering_rendering_state const);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::playing::audio_buffering_setup_state const &);
std::ostream &operator<<(std::ostream &, yas::playing::audio_buffering_rendering_state const &);
