//
//  module_set_utils.cpp
//

#include "module_set_utils.h"

using namespace yas;
using namespace yas::proc;

module_set_event_type proc::to_module_set_event_type(observing::vector::event_type const &vector_type) {
    switch (vector_type) {
        case observing::vector::event_type::any:
            return module_set_event_type::any;
        case observing::vector::event_type::inserted:
            return module_set_event_type::inserted;
        case observing::vector::event_type::replaced:
            return module_set_event_type::replaced;
        case observing::vector::event_type::erased:
            return module_set_event_type::erased;
    }
}
