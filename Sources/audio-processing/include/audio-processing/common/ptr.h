//
//  ptr.h
//

#pragma once

#include <memory>

namespace yas::proc {
class track;
class timeline;
class module;
class module_set;
class event;
class number_event;
class signal_event;

using track_ptr = std::shared_ptr<track>;
using timeline_ptr = std::shared_ptr<timeline>;
using module_ptr = std::shared_ptr<module>;
using module_set_ptr = std::shared_ptr<module_set>;
using number_event_ptr = std::shared_ptr<number_event>;
using signal_event_ptr = std::shared_ptr<signal_event>;
}  // namespace yas::proc
