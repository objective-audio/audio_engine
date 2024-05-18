//
//  timeline_module.cpp
//

#include "sub_timeline_module.h"

#include <audio-processing/event/signal_event.h>
#include <audio-processing/module/module.h>
#include <audio-processing/sync_source/sync_source.h>
#include <audio-processing/timeline/timeline.h>

using namespace yas;
using namespace yas::proc;

namespace yas::proc {
namespace sub_timeline {
    struct context {
        timeline_ptr const timeline;

        context(proc::timeline_ptr const &timeline) : timeline(timeline) {
        }
    };

    std::shared_ptr<context> make_context(timeline_ptr const &timeline) {
        return std::make_shared<context>(timeline);
    }
}  // namespace sub_timeline
}  // namespace yas::proc

proc::module_ptr proc::make_module(timeline_ptr const &timeline, frame_index_t const offset) {
    auto context = sub_timeline::make_context(timeline);

    auto make_processors = [context = std::move(context), offset] {
        auto processor = [context, offset](time::range const &time_range, connector_map_t const &input_connectors,
                                           connector_map_t const &output_connectors, stream &stream) mutable {
            proc::stream sub_stream{stream.sync_source()};

            for (auto const &connector : input_connectors) {
                auto const &ch_idx = connector.second.channel_index;

                if (stream.has_channel(ch_idx)) {
                    auto const &input_channel = stream.channel(ch_idx);
                    auto const &co_idx = connector.first;

                    if (sub_stream.has_channel(co_idx)) {
                        throw "channel already exists in sub_stream.";
                    }

                    sub_stream.add_channel(co_idx, input_channel.copied_events(time_range, -offset));
                }
            }

            context->timeline->process(time_range.offset(-offset), sub_stream);

            for (auto const &connector : output_connectors) {
                auto const &co_idx = connector.first;

                if (sub_stream.has_channel(co_idx)) {
                    auto const &ch_idx = connector.second.channel_index;
                    auto &out_channel = stream.add_channel(ch_idx);
                    auto const &sub_channel = sub_stream.channel(co_idx);

                    out_channel.erase_events(time_range);

                    for (auto &event_pair : sub_channel.events()) {
                        time const &time = event_pair.first;
                        event const &event = event_pair.second;
                        if (time.is_range_type()) {
                            if (auto const &signal = event.get<signal_event>()) {
                                out_channel.combine_signal_event(time.get<time::range>().offset(offset), signal);
                            }
                        } else {
                            out_channel.insert_event(time.offset(offset), event);
                        }
                    }
                }
            }
        };

        return module::processors_t{std::move(processor)};
    };

    return proc::module::make_shared(std::move(make_processors));
}
