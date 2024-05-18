//
//  timeline_container.cpp
//

#include "timeline_container.h"

using namespace yas;
using namespace yas::playing;

timeline_container::timeline_container(std::string const &identifier, sample_rate_t const sample_rate,
                                       std::optional<proc::timeline_ptr> const &timeline)
    : _identifier(identifier), _sample_rate(sample_rate), _timeline(timeline) {
}

std::string const &timeline_container::identifier() const {
    return this->_identifier;
}

sample_rate_t const &timeline_container::sample_rate() const {
    return this->_sample_rate;
}

std::optional<proc::timeline_ptr> const &timeline_container::timeline() const {
    return this->_timeline;
}

bool timeline_container::is_available() const {
    return !this->_identifier.empty() && this->_sample_rate > 0 && this->_timeline.has_value();
}

timeline_container_ptr timeline_container::make_shared(std::string const &identifier, sample_rate_t const sample_rate,
                                                       std::optional<proc::timeline_ptr> const &timeline) {
    return timeline_container_ptr(new timeline_container{identifier, sample_rate, timeline});
}

timeline_container_ptr timeline_container::make_shared_empty() {
    return timeline_container_ptr(new timeline_container{"", 0, std::nullopt});
}
