//
//  yas_audio_avf_au_parameter_core.mm
//

#include "yas_audio_avf_au_parameter_core.h"

using namespace yas;

audio::avf_au_parameter_core::avf_au_parameter_core(objc_ptr<AUParameter *> const &objc_param)
    : objc_parameter(objc_param) {
}

audio::avf_au_parameter_core_ptr audio::avf_au_parameter_core::make_shared(objc_ptr<AUParameter *> const &objc_param) {
    return avf_au_parameter_core_ptr(new avf_au_parameter_core{objc_param});
}
