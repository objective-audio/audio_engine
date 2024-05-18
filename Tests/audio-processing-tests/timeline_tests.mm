//
//  timeline_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/each_index.h>
#import <audio-processing/timeline/timeline.h>

using namespace yas;
using namespace yas::proc;

@interface timeline_tests : XCTestCase

@end

@implementation timeline_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    auto const timeline = timeline::make_shared();

    XCTAssertEqual(timeline->track_count(), 0);
}

- (void)test_insert_track {
    auto const timeline = timeline::make_shared();

    auto const track1 = track::make_shared();
    auto const track2 = track::make_shared();
    auto const track_minus_1 = track::make_shared();

    timeline->insert_track(1, track1);
    timeline->insert_track(2, track2);
    timeline->insert_track(-1, track_minus_1);

    XCTAssertEqual(timeline->track_count(), 3);

    XCTAssertTrue(timeline->has_track(1));
    XCTAssertTrue(timeline->has_track(2));
    XCTAssertTrue(timeline->has_track(-1));

    XCTAssertTrue(timeline->track(1) == track1);
    XCTAssertTrue(timeline->track(2) == track2);
    XCTAssertTrue(timeline->track(-1) == track_minus_1);

    XCTAssertFalse(timeline->has_track(0));
}

- (void)test_insert_track_result {
    auto const timeline = timeline::make_shared();

    auto const track_a = track::make_shared();

    XCTAssertTrue(timeline->insert_track(0, track_a));

    auto const track_b = track::make_shared();

    XCTAssertFalse(timeline->insert_track(0, track_b));

    XCTAssertEqual(timeline->track(0), track_a);
}

- (void)test_erase_track {
    auto const timeline = timeline::make_shared();

    timeline->insert_track(10, track::make_shared());
    timeline->insert_track(11, track::make_shared());

    timeline->erase_track(10);

    XCTAssertEqual(timeline->track_count(), 1);
    XCTAssertFalse(timeline->has_track(10));
    XCTAssertTrue(timeline->has_track(11));
}

- (void)test_erase_all_tracks {
    auto const timeline = timeline::make_shared();

    timeline->insert_track(20, track::make_shared());
    timeline->insert_track(21, track::make_shared());

    timeline->erase_all_tracks();

    XCTAssertEqual(timeline->track_count(), 0);
    XCTAssertFalse(timeline->has_track(20));
    XCTAssertFalse(timeline->has_track(21));
}

- (void)test_process {
    auto const timeline = timeline::make_shared();

    proc::time called_send_time = nullptr;
    proc::time called_receive_time = nullptr;

    auto process_signal = signal_event::make_shared<int16_t>(2);

    auto clear = [&called_send_time, &called_receive_time, &process_signal]() {
        called_send_time = {};
        called_receive_time = {};
        auto &vec = process_signal->vector<int16_t>();
        for (auto const &idx : make_each_index(2)) {
            vec[idx] = 0;
        }
    };

    // setup track1 > インデックスをそのままセット

    auto const track1 = track::make_shared();

    auto module1 = module::make_shared([] {
        auto send_handler1 = [](time::range const &time_range, sync_source const &, channel_index_t const ch_idx,
                                connector_index_t const co_idx, int16_t *const signal_ptr) {
            if (co_idx == 0) {
                for (auto const &idx : make_each_index(time_range.length)) {
                    signal_ptr[idx] = idx;
                }
            }
        };
        return module::processors_t{make_send_signal_processor<int16_t>({std::move(send_handler1)})};
    });
    module1->connect_output(0, 0);

    track1->push_back_module(module1, {0, 2});
    timeline->insert_track(1, track1);

    // setup track2 > +1する

    auto const track2 = track::make_shared();

    auto send_handler2 = [&process_signal, &called_send_time](
                             time::range const &time_range, sync_source const &, channel_index_t const ch_idx,
                             connector_index_t const co_idx, int16_t *const signal_ptr) {
        called_send_time = proc::time{time_range};

        if (co_idx == 0) {
            auto &vec = process_signal->vector<int16_t>();
            for (auto const &idx : make_each_index(time_range.length)) {
                signal_ptr[idx] = vec[idx];
            }
        }
    };

    auto receive_handler2 = [&process_signal, &called_receive_time](
                                time::range const &time_range, sync_source const &, channel_index_t const ch_idx,
                                connector_index_t const co_idx, int16_t const *const signal_ptr) {
        called_receive_time = proc::time{time_range};

        if (co_idx == 0) {
            auto &vec = process_signal->vector<int16_t>();
            for (auto const &idx : make_each_index(time_range.length)) {
                vec[idx] = signal_ptr[idx] + 1;
            }
        }
    };

    auto module2 =
        module::make_shared([receive_handler2 = std::move(receive_handler2), send_handler2 = std::move(send_handler2)] {
            auto receive_processor2 = make_receive_signal_processor<int16_t>({std::move(receive_handler2)});
            auto send_processor2 = make_send_signal_processor<int16_t>({std::move(send_handler2)});
            return module::processors_t{{std::move(receive_processor2), std::move(send_processor2)}};
        });

    module2->connect_input(0, 0);
    module2->connect_output(0, 0);

    track2->push_back_module(module2, {0, 2});
    timeline->insert_track(2, track2);

    {
        stream stream{sync_source{1, 2}};

        timeline->process({0, 2}, stream);

        XCTAssertTrue((called_send_time == proc::time{0, 2}));
        XCTAssertTrue((called_receive_time == proc::time{0, 2}));

        XCTAssertTrue(stream.has_channel(0));
        auto &events = stream.channel(0).events();
        XCTAssertEqual(events.size(), 1);
        auto const &vec = events.cbegin()->second.get<signal_event>()->vector<int16_t>();
        XCTAssertEqual(vec.size(), 2);
        XCTAssertEqual(vec[0], 1);
        XCTAssertEqual(vec[1], 2);
    }

    {
        clear();

        stream stream{sync_source{1, 2}};

        timeline->process({-1, 2}, stream);

        XCTAssertTrue((called_send_time == proc::time{0, 1}));
        XCTAssertTrue((called_receive_time == proc::time{0, 1}));

        XCTAssertTrue(stream.has_channel(0));
        auto &events = stream.channel(0).events();
        XCTAssertEqual(events.size(), 1);
        auto const &vec = events.cbegin()->second.get<signal_event>()->vector<int16_t>();
        XCTAssertEqual(vec.size(), 1);
        XCTAssertEqual(vec[0], 1);
    }

    {
        clear();

        stream stream{sync_source{1, 2}};

        timeline->process({1, 2}, stream);

        XCTAssertTrue((called_send_time == proc::time{1, 1}));
        XCTAssertTrue((called_receive_time == proc::time{1, 1}));

        XCTAssertTrue(stream.has_channel(0));
        auto &events = stream.channel(0).events();
        XCTAssertEqual(events.size(), 1);
        auto const &vec = events.cbegin()->second.get<signal_event>()->vector<int16_t>();
        XCTAssertEqual(vec.size(), 1);
        XCTAssertEqual(vec[0], 1);
    }

    {
        clear();

        stream stream{sync_source{1, 2}};

        timeline->process({3, 2}, stream);

        XCTAssertFalse(stream.has_channel(0));
    }
}

- (void)test_process_with_handler {
    auto const timeline = timeline::make_shared();

    channel_index_t const ch_idx = 0;
    length_t const process_length = 5;

    auto const track = track::make_shared();
    auto fast_each = make_fast_each<frame_index_t>(process_length);
    while (yas_each_next(fast_each)) {
        auto const &idx = yas_each_index(fast_each);
        auto module = make_signal_module<int8_t>(idx);
        module->connect_output(to_connector_index(constant::output::value), ch_idx);
        track->push_back_module(std::move(module), {idx, 1});
    }
    timeline->insert_track(0, track);

    std::vector<std::pair<time::range, std::vector<int8_t>>> called;

    timeline->process(time::range{0, process_length}, sync_source{1, 2},
                      [&ch_idx, &called](time::range const &time_range, stream const &stream) {
                          auto const &channel = stream.channel(ch_idx);
                          auto const &pair = *channel.events().cbegin();
                          auto const signal = pair.second.get<signal_event>();
                          called.emplace_back(std::make_pair(pair.first.get<time::range>(), signal->vector<int8_t>()));
                          return continuation::keep;
                      });

    XCTAssertEqual(called.size(), 3);

    XCTAssertEqual(called[0].first, (time::range{0, 2}));
    XCTAssertEqual(called[0].second[0], 0);
    XCTAssertEqual(called[0].second[1], 1);

    XCTAssertEqual(called[1].first, (time::range{2, 2}));
    XCTAssertEqual(called[1].second[0], 2);
    XCTAssertEqual(called[1].second[1], 3);

    XCTAssertEqual(called[2].first, (time::range{4, 1}));
    XCTAssertEqual(called[2].second[0], 4);
}

- (void)test_process_with_track_handler {
    auto const timeline = timeline::make_shared();

    channel_index_t const ch_idx = 0;
    length_t const process_length = 5;

    auto trk_each = make_fast_each(2);
    while (yas_each_next(trk_each)) {
        auto const &trk_idx = yas_each_index(trk_each);
        auto const track = track::make_shared();
        auto frame_each = make_fast_each<frame_index_t>(process_length);
        while (yas_each_next(frame_each)) {
            auto const &frame_idx = yas_each_index(frame_each);
            int8_t const value = frame_idx + 10 * trk_idx;
            auto module = make_signal_module<int8_t>(value);
            module->connect_output(to_connector_index(constant::output::value), ch_idx);
            track->push_back_module(std::move(module), {frame_idx, 1});
        }
        timeline->insert_track(trk_idx, track);
    }

    std::vector<std::tuple<time::range, std::optional<track_index_t>, std::vector<int8_t>>> called;

    timeline->process(
        time::range{0, process_length}, sync_source{1, 2},
        [&ch_idx, &called](time::range const &time_range, stream const &stream,
                           std::optional<track_index_t> const &trk_idx) {
            auto const &channel = stream.channel(ch_idx);
            auto const &pair = *channel.events().cbegin();
            auto const signal = pair.second.get<signal_event>();
            called.push_back(std::make_tuple(pair.first.get<time::range>(), trk_idx, signal->vector<int8_t>()));
            return continuation::keep;
        });

    XCTAssertEqual(called.size(), 9);

    XCTAssertEqual(std::get<0>(called[0]), (time::range{0, 2}));
    XCTAssertEqual(std::get<1>(called[0]), 0);
    XCTAssertEqual(std::get<2>(called[0])[0], 0);
    XCTAssertEqual(std::get<2>(called[0])[1], 1);

    XCTAssertEqual(std::get<0>(called[1]), (time::range{0, 2}));
    XCTAssertEqual(std::get<1>(called[1]), 1);
    XCTAssertEqual(std::get<2>(called[1])[0], 10);
    XCTAssertEqual(std::get<2>(called[1])[1], 11);

    XCTAssertEqual(std::get<0>(called[2]), (time::range{0, 2}));
    XCTAssertEqual(std::get<1>(called[2]), std::nullopt);
    XCTAssertEqual(std::get<2>(called[2])[0], 10);
    XCTAssertEqual(std::get<2>(called[2])[1], 11);

    XCTAssertEqual(std::get<0>(called[3]), (time::range{2, 2}));
    XCTAssertEqual(std::get<1>(called[3]), 0);
    XCTAssertEqual(std::get<2>(called[3])[0], 2);
    XCTAssertEqual(std::get<2>(called[3])[1], 3);

    XCTAssertEqual(std::get<0>(called[4]), (time::range{2, 2}));
    XCTAssertEqual(std::get<1>(called[4]), 1);
    XCTAssertEqual(std::get<2>(called[4])[0], 12);
    XCTAssertEqual(std::get<2>(called[4])[1], 13);

    XCTAssertEqual(std::get<0>(called[5]), (time::range{2, 2}));
    XCTAssertEqual(std::get<1>(called[5]), std::nullopt);
    XCTAssertEqual(std::get<2>(called[5])[0], 12);
    XCTAssertEqual(std::get<2>(called[5])[1], 13);

    XCTAssertEqual(std::get<0>(called[6]), (time::range{4, 1}));
    XCTAssertEqual(std::get<1>(called[6]), 0);
    XCTAssertEqual(std::get<2>(called[6])[0], 4);

    XCTAssertEqual(std::get<0>(called[7]), (time::range{4, 1}));
    XCTAssertEqual(std::get<1>(called[7]), 1);
    XCTAssertEqual(std::get<2>(called[7])[0], 14);

    XCTAssertEqual(std::get<0>(called[8]), (time::range{4, 1}));
    XCTAssertEqual(std::get<1>(called[8]), std::nullopt);
    XCTAssertEqual(std::get<2>(called[8])[0], 14);
}

- (void)test_stop_process_with_handler {
    auto const timeline = timeline::make_shared();

    length_t const process_length = 10;
    frame_index_t last_frame = 0;

    timeline->process(time::range{0, process_length}, sync_source{1, 1},
                      [&last_frame](time::range const &time_range, stream const &) {
                          last_frame = time_range.frame;

                          if (time_range.frame == 5) {
                              return continuation::abort;
                          }
                          return continuation::keep;
                      });

    XCTAssertEqual(last_frame, 5);
}

- (void)test_total_range {
    auto const timeline = timeline::make_shared();

    XCTAssertFalse(timeline->total_range());

    auto const track_0 = track::make_shared();
    track_0->push_back_module(module::make_shared([] { return module::processors_t{}; }), {0, 1});
    timeline->insert_track(0, track_0);

    XCTAssertEqual(timeline->total_range(), (time::range{0, 1}));

    auto const track_1 = track::make_shared();
    track_1->push_back_module(module::make_shared([] { return module::processors_t{}; }), {1, 1});
    timeline->insert_track(1, track_1);

    XCTAssertEqual(timeline->total_range(), (time::range{0, 2}));

    auto const track_2 = track::make_shared();
    track_2->push_back_module(module::make_shared([] { return module::processors_t{}; }), {99, 1});
    timeline->insert_track(2, track_2);

    XCTAssertEqual(timeline->total_range(), (time::range{0, 100}));

    auto const track_3 = track::make_shared();
    track_3->push_back_module(module::make_shared([] { return module::processors_t{}; }), {-10, 1});
    timeline->insert_track(3, track_3);

    XCTAssertEqual(timeline->total_range(), (time::range{-10, 110}));
}

- (void)test_copy {
    std::vector<int> called;

    auto index = std::make_shared<int>(0);
    auto module = module::make_shared([index = std::move(index), &called] {
        auto processor = [index = *index, &called](time::range const &, connector_map_t const &,
                                                   connector_map_t const &, stream &) { called.push_back(index); };
        ++(*index);
        return module::processors_t{std::move(processor)};
    });

    auto const track = track::make_shared();
    track->push_back_module(std::move(module), {0, 1});

    auto const timeline = timeline::make_shared();
    timeline->insert_track(0, std::move(track));

    auto copied_timeline = timeline->copy();

    XCTAssertEqual(copied_timeline->tracks().size(), 1);
    XCTAssertTrue(copied_timeline->has_track(0));
    XCTAssertEqual(copied_timeline->track(0)->module_sets().size(), 1);
    XCTAssertEqual(copied_timeline->track(0)->module_sets().count({0, 1}), 1);

    proc::stream stream{sync_source{1, 1}};

    timeline->process({0, 1}, stream);

    XCTAssertEqual(called.size(), 1);
    XCTAssertEqual(called.at(0), 0);

    copied_timeline->process({0, 1}, stream);

    XCTAssertEqual(called.size(), 2);
    XCTAssertEqual(called.at(1), 1);
}

- (void)test_observe_timeline {
    auto const timeline = timeline::make_shared();

    std::vector<timeline_event_type> received;

    auto canceller = timeline->observe([&received](auto const &event) { received.emplace_back(event.type); }).sync();

    XCTAssertEqual(received.size(), 1);
    XCTAssertEqual(received.at(0), timeline_event_type::any);

    auto const track1 = track::make_shared();
    timeline->insert_track(1, track1);

    XCTAssertEqual(received.size(), 2);
    XCTAssertEqual(received.at(1), timeline_event_type::inserted);

    timeline->erase_track(1);

    XCTAssertEqual(received.size(), 3);
    XCTAssertEqual(received.at(2), timeline_event_type::erased);

    auto const track2 = track::make_shared();
    auto const track3 = track::make_shared();
    timeline->replace_tracks({{2, track2}, {3, track3}});

    XCTAssertEqual(received.size(), 4);
    XCTAssertEqual(received.at(3), timeline_event_type::any);

    timeline->erase_all_tracks();

    XCTAssertEqual(received.size(), 5);
    XCTAssertEqual(received.at(4), timeline_event_type::any);

    timeline->erase_all_tracks();

    XCTAssertEqual(received.size(), 5);

    canceller->cancel();
}

- (void)test_observe_track {
    auto const track1 = track::make_shared();
    auto const track2 = track::make_shared();
    auto module1 = module::make_shared([] { return module::processors_t{}; });
    auto module2 = module::make_shared([] { return module::processors_t{}; });
    auto const timeline = timeline::make_shared({{1, track1}});

    std::vector<timeline_event_type> received;

    auto canceller = timeline->observe([&received](auto const &event) { received.emplace_back(event.type); }).end();

    XCTAssertEqual(received.size(), 0);

    track1->push_back_module(module1, {0, 1});

    XCTAssertEqual(received.size(), 1);
    XCTAssertEqual(received.at(0), timeline_event_type::relayed);

    timeline->insert_track(2, track2);

    XCTAssertEqual(received.size(), 2);

    track2->push_back_module(module2, {0, 1});

    XCTAssertEqual(received.size(), 3);
    XCTAssertEqual(received.at(2), timeline_event_type::relayed);

    timeline->erase_track(1);

    XCTAssertEqual(received.size(), 4);

    track1->erase_module(module1);

    XCTAssertEqual(received.size(), 4);

    timeline->erase_track(2);

    XCTAssertEqual(received.size(), 5);

    track2->erase_module(module2);

    XCTAssertEqual(received.size(), 5);

    canceller->cancel();
}

@end
