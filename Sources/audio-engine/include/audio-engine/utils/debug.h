//
//  debug.h
//

#pragma once

#if DEBUG

#include <string>

namespace yas::audio {
void set_log_enabled(bool const);
void log(std::string const &);
}  // namespace yas::audio

#define yas_audio_set_log_enabled(__v) yas::audio::set_log_enabled(__v)
#define yas_audio_log(__v) yas::audio::log(__v)

#else

#define yas_audio_set_log_enabled(__v)
#define yas_audio_log(__v)

#endif
