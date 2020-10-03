//
//  yas_audio_avf_au_parameter_core.h
//

#pragma once

#include <cpp_utils/yas_objc_ptr.h>
#include "yas_audio_ptr.h"

@class AUParameter;

namespace yas::audio {
struct avf_au_parameter_core {
    objc_ptr<AUParameter *> const objc_parameter;

    static avf_au_parameter_core_ptr make_shared(AUParameter *const);

   private:
    avf_au_parameter_core(AUParameter *const);
};
}  // namespace yas::audio
