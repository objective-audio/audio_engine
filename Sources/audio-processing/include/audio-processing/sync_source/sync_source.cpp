//
//  sync_source.cpp
//

#include "sync_source.h"

using namespace yas;
using namespace yas::proc;

proc::sync_source::sync_source(sample_rate_t const sample_rate, length_t const slice_length)
    : sample_rate(sample_rate), slice_length(slice_length) {
    if (this->sample_rate == 0) {
        throw "sample_rate is zero.";
    } else if (this->slice_length == 0) {
        throw "slice_length is zero.";
    }
}

bool proc::sync_source::operator==(sync_source const &rhs) const {
    return this->sample_rate == rhs.sample_rate && this->slice_length == rhs.slice_length;
}

bool proc::sync_source::operator!=(sync_source const &rhs) const {
    return this->sample_rate != rhs.sample_rate || this->slice_length != rhs.slice_length;
}
