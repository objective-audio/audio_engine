//
//  yas_audio_types.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_types.h"

using namespace yas;

std::string yas::to_string(const direction &dir)
{
    switch (dir) {
        case direction::output:
            return "output";
        case direction::input:
            return "input";
    }
}