//
//  player_resource_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

namespace yas::playing::player_resource_test {
struct reading_resource : reading_resource_for_player_resource {
    state_t state() const override {
        return state_t::initial;
    }

    audio::pcm_buffer *buffer_on_render() override {
        return nullptr;
    }

    bool needs_create_on_render(sample_rate_t const sample_rate, audio::pcm_format const pcm_format,
                                uint32_t const length) const override {
        return false;
    }

    void set_creating_on_render(sample_rate_t const sample_rate, audio::pcm_format const pcm_format,
                                uint32_t const length) override {
    }

    void create_buffer_on_task() override {
    }
};

struct buffering_resource : buffering_resource_for_player_resource {
    setup_state_t setup_state() const override {
        return setup_state_t::initial;
    }
    rendering_state_t rendering_state() const override {
        return rendering_state_t::waiting;
    }
    std::size_t element_count() const override {
        return 0;
    }
    std::size_t channel_count_on_render() const override {
        return 0;
    }
    sample_rate_t fragment_length_on_render() const override {
        return 0;
    }

    void set_creating_on_render(sample_rate_t const sample_rate, audio::pcm_format const &,
                                uint32_t const ch_count) override {
    }
    bool needs_create_on_render(sample_rate_t const sample_rate, audio::pcm_format const &,
                                uint32_t const ch_count) override {
        return false;
    }

    void create_buffer_on_task() override {
    }

    void set_all_writing_on_render(frame_index_t const) override {
    }
    void write_all_elements_on_task() override {
    }
    void advance_on_render(fragment_index_t const) override {
    }
    bool write_elements_if_needed_on_task() override {
        return false;
    }
    void overwrite_element_on_render(element_address const &) override {
    }

    bool read_into_buffer_on_render(audio::pcm_buffer *, channel_index_t const, frame_index_t const) override {
        return false;
    }

    bool needs_all_writing_on_render() const override {
        return false;
    }
    void set_channel_mapping_request_on_main(channel_mapping const &) override {
    }
    void set_identifier_request_on_main(std::string const &) override {
    }
};

struct cpp {
    std::shared_ptr<reading_resource> const reading = std::make_shared<player_resource_test::reading_resource>();
    std::shared_ptr<buffering_resource> const buffering = std::make_shared<player_resource_test::buffering_resource>();

    player_resource_ptr make_resource() {
        return player_resource::make_shared(this->reading, this->buffering);
    }
};
}  // namespace yas::playing::player_resource_test

@interface player_resource_tests : XCTestCase

@end

@implementation player_resource_tests {
    player_resource_test::cpp _cpp;
}

- (void)test_constructor {
    auto const resource = self->_cpp.make_resource();

    XCTAssertEqual(resource->reading(), self->_cpp.reading);
    XCTAssertEqual(resource->buffering(), self->_cpp.buffering);
}

- (void)test_is_playing {
    auto const resource = self->_cpp.make_resource();

    XCTAssertFalse(resource->is_playing_on_render());

    resource->set_playing_on_main(true);

    XCTAssertTrue(resource->is_playing_on_render());
}

- (void)test_seek {
    auto const resource = self->_cpp.make_resource();

    XCTAssertEqual(resource->pull_seek_frame_on_render(), std::nullopt);
    XCTAssertFalse(resource->is_seeking_on_main());

    resource->seek_on_main(666);

    XCTAssertTrue(resource->is_seeking_on_main());

    XCTAssertEqual(resource->pull_seek_frame_on_render(), 666);

    XCTAssertTrue(resource->is_seeking_on_main());

    XCTAssertEqual(resource->pull_seek_frame_on_render(), std::nullopt);

    resource->set_current_frame_on_render(666);

    XCTAssertFalse(resource->is_seeking_on_main());
}

- (void)test_current_frame {
    auto const resource = self->_cpp.make_resource();

    XCTAssertEqual(resource->current_frame(), 0);

    resource->set_current_frame_on_render(1);

    XCTAssertEqual(resource->current_frame(), 1);
}

- (void)test_overwrite_request {
    auto const resource = self->_cpp.make_resource();

    std::vector<player_resource_for_player::overwrite_requests_t> called;

    auto requests = [&called](player_resource_for_player::overwrite_requests_t const &requests) {
        called.emplace_back(requests);
    };

    [XCTContext runActivityNamed:@"初期状態は実行される"
                           block:[&called, &resource, &requests](id<XCTActivity> activity) {
                               resource->perform_overwrite_requests_on_render(requests);

                               XCTAssertEqual(called.size(), 1);
                               XCTAssertEqual(called.at(0).size(), 0);
                           }];

    called.clear();

    [XCTContext runActivityNamed:@"実行された後は何もしなければ実行されなくなる"
                           block:[&called, &resource, &requests](id<XCTActivity> activity) {
                               resource->perform_overwrite_requests_on_render(requests);

                               XCTAssertEqual(called.size(), 0);
                           }];

    called.clear();

    [XCTContext runActivityNamed:@"リクエストを追加して実行される"
                           block:[&called, &resource, &requests](id<XCTActivity> activity) {
                               resource->add_overwrite_request_on_main(
                                   {.file_channel_index = std::nullopt, .fragment_range = {.index = 0, .length = 1}});

                               resource->perform_overwrite_requests_on_render(requests);

                               XCTAssertEqual(called.size(), 1);
                               XCTAssertEqual(called.at(0).size(), 1);
                               XCTAssertEqual(called.at(0).at(0).file_channel_index, std::nullopt);
                               XCTAssertEqual(called.at(0).at(0).fragment_range.index, 0);
                               XCTAssertEqual(called.at(0).at(0).fragment_range.length, 1);
                           }];

    called.clear();

    [XCTContext runActivityNamed:@"実行された後は何もしなければ実行されなくなる"
                           block:[&called, &resource, &requests](id<XCTActivity> activity) {
                               resource->perform_overwrite_requests_on_render(requests);

                               XCTAssertEqual(called.size(), 0);
                           }];

    [XCTContext runActivityNamed:@"リクエストを複数追加して実行される"
                           block:[&called, &resource, &requests](id<XCTActivity> activity) {
                               resource->add_overwrite_request_on_main(
                                   {.file_channel_index = 1, .fragment_range = {.index = 2, .length = 1}});
                               resource->add_overwrite_request_on_main(
                                   {.file_channel_index = 3, .fragment_range = {.index = 4, .length = 1}});

                               resource->perform_overwrite_requests_on_render(requests);

                               XCTAssertEqual(called.size(), 1);
                               XCTAssertEqual(called.at(0).size(), 2);
                               XCTAssertEqual(called.at(0).at(0).file_channel_index, 1);
                               XCTAssertEqual(called.at(0).at(0).fragment_range.index, 2);
                               XCTAssertEqual(called.at(0).at(0).fragment_range.length, 1);
                               XCTAssertEqual(called.at(0).at(1).file_channel_index, 3);
                               XCTAssertEqual(called.at(0).at(1).fragment_range.index, 4);
                               XCTAssertEqual(called.at(0).at(1).fragment_range.length, 1);
                           }];

    called.clear();

    [XCTContext runActivityNamed:@"リクエストを追加してもリセットしたら実行されない"
                           block:[&called, &resource, &requests](id<XCTActivity> activity) {
                               resource->add_overwrite_request_on_main(
                                   {.file_channel_index = 5, .fragment_range = {.index = 6, .length = 1}});

                               resource->reset_overwrite_requests_on_render();

                               resource->perform_overwrite_requests_on_render(requests);

                               XCTAssertEqual(called.size(), 0);
                           }];
}

@end
