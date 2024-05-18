//
//  player_buffering_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import "player_test_utils.h"

using namespace yas;
using namespace yas::playing;

@interface player_buffering_tests : XCTestCase

@end

@implementation player_buffering_tests {
    player_test::cpp _cpp;
}

- (void)tearDown {
    self->_cpp.reset();
}

- (void)test_setup_state_initial {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.skip_reading();

    auto const &buffering = self->_cpp.buffering;

    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_set_creating;

    buffering->setup_state_handler = [] { return audio_buffering_setup_state::initial; };
    buffering->set_creating_handler = [&called_set_creating](sample_rate_t sample_rate, audio::pcm_format pcm_format,
                                                             uint32_t ch_count) {
        called_set_creating.emplace_back(sample_rate, pcm_format, ch_count);
    };

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_set_creating.size(), 1);
    XCTAssertEqual(std::get<0>(called_set_creating.at(0)), 4);
    XCTAssertEqual(std::get<1>(called_set_creating.at(0)), audio::pcm_format::int16);
    XCTAssertEqual(std::get<2>(called_set_creating.at(0)), 3);
}

- (void)test_setup_state_creating {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.skip_reading();

    auto const &buffering = self->_cpp.buffering;

    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_set_creating;

    buffering->setup_state_handler = [] { return audio_buffering_setup_state::creating; };
    buffering->set_creating_handler = [&called_set_creating](sample_rate_t sample_rate, audio::pcm_format pcm_format,
                                                             uint32_t ch_count) {
        called_set_creating.emplace_back(sample_rate, pcm_format, ch_count);
    };

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_set_creating.size(), 0);
}

- (void)test_setup_state_rendering {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.skip_reading();

    auto const &buffering = self->_cpp.buffering;

    bool needs_create = true;
    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_set_creating;
    std::vector<std::tuple<double, audio::pcm_format, uint32_t>> called_needs_create;

    buffering->setup_state_handler = [] { return audio_buffering_setup_state::rendering; };
    buffering->set_creating_handler = [&called_set_creating](sample_rate_t sample_rate, audio::pcm_format pcm_format,
                                                             uint32_t ch_count) {
        called_set_creating.emplace_back(sample_rate, pcm_format, ch_count);
    };
    buffering->needs_create_handler = [&called_needs_create, &needs_create](
                                          sample_rate_t sample_rate, audio::pcm_format pcm_format, uint32_t ch_count) {
        called_needs_create.emplace_back(sample_rate, pcm_format, ch_count);
        return needs_create;
    };
    buffering->rendering_state_handler = [] { return audio_buffering_rendering_state::all_writing; };

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_set_creating.size(), 1);

    needs_create = false;

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_set_creating.size(), 1);
}

- (void)test_rendering_state_waiting {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.skip_buffering_setup();

    auto const &buffering = self->_cpp.buffering;
    auto const &resource = self->_cpp.resource;

    std::size_t called_reset_overwrite = 0;
    std::size_t called_pull_seek = 0;
    std::size_t called_current_frame = 0;
    std::vector<frame_index_t> called_set_all_writing;
    std::vector<frame_index_t> called_set_current_frame;
    std::size_t called_needs_all_writing = 0;

    frame_index_t current_frame = 100;
    std::optional<frame_index_t> seek_frame = std::nullopt;
    bool needs_all_writing = false;

    buffering->rendering_state_handler = [] { return audio_buffering_rendering_state::waiting; };
    resource->reset_overwrite_requests_handler = [&called_reset_overwrite] { ++called_reset_overwrite; };
    resource->pull_seek_frame_handler = [&seek_frame, &called_pull_seek] {
        ++called_pull_seek;
        return seek_frame;
    };
    resource->current_frame_handler = [&called_current_frame, &current_frame] {
        ++called_current_frame;
        return current_frame;
    };
    resource->set_current_frame_handler = [&called_set_current_frame](frame_index_t frame) {
        called_set_current_frame.emplace_back(frame);
    };
    buffering->set_all_writing_handler = [&called_set_all_writing](frame_index_t frame) {
        called_set_all_writing.emplace_back(frame);
    };

    buffering->needs_all_writing_handler = [&needs_all_writing, &called_needs_all_writing] {
        ++called_needs_all_writing;
        return needs_all_writing;
    };

    // seek_frameなし、needs_all_writingなし

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_reset_overwrite, 1);
    XCTAssertEqual(called_pull_seek, 1);
    XCTAssertEqual(called_needs_all_writing, 1);
    XCTAssertEqual(called_current_frame, 1);
    XCTAssertEqual(called_set_all_writing.size(), 1);
    XCTAssertEqual(called_set_all_writing.at(0), 100);
    XCTAssertEqual(called_set_current_frame.size(), 0);

    // seek_frameあり、needs_all_writingなし

    seek_frame = 200;

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_reset_overwrite, 2);
    XCTAssertEqual(called_pull_seek, 2);
    XCTAssertEqual(called_needs_all_writing, 2);
    XCTAssertEqual(called_current_frame, 1);
    XCTAssertEqual(called_set_all_writing.size(), 2);
    XCTAssertEqual(called_set_all_writing.at(1), 200);
    XCTAssertEqual(called_set_current_frame.size(), 1);
    XCTAssertEqual(called_set_current_frame.at(0), 200);

    // seek_frameなし、needs_all_writingあり

    seek_frame = std::nullopt;
    needs_all_writing = true;

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_reset_overwrite, 3);
    XCTAssertEqual(called_pull_seek, 3);
    XCTAssertEqual(called_needs_all_writing, 3);
    XCTAssertEqual(called_current_frame, 2);
    XCTAssertEqual(called_set_all_writing.size(), 3);
    XCTAssertEqual(called_set_current_frame.size(), 1);
}

- (void)test_rendering_state_all_writing {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.skip_buffering_setup();

    auto const &buffering = self->_cpp.buffering;
    auto const &resource = self->_cpp.resource;

    bool called_pull_seek = false;
    bool called_needs_all_writing = false;

    buffering->rendering_state_handler = [] { return audio_buffering_rendering_state::all_writing; };
    resource->pull_seek_frame_handler = [&called_pull_seek] {
        called_pull_seek = true;
        return std::nullopt;
    };
    buffering->needs_all_writing_handler = [&called_needs_all_writing] {
        called_needs_all_writing = true;
        return false;
    };

    self->_cpp.rendering_handler(&buffer);

    XCTAssertFalse(called_pull_seek);
    XCTAssertFalse(called_needs_all_writing);
}

- (void)test_rendering_state_advancing {
    audio::pcm_buffer buffer = player_test::cpp::make_out_buffer();

    self->_cpp.skip_buffering_setup();

    auto const &buffering = self->_cpp.buffering;
    auto const &resource = self->_cpp.resource;

    std::size_t called_pull_seek = 0;
    std::size_t called_needs_all_writing = 0;

    buffering->rendering_state_handler = [] { return audio_buffering_rendering_state::advancing; };
    resource->reset_overwrite_requests_handler = [] {};
    resource->pull_seek_frame_handler = [&called_pull_seek] {
        ++called_pull_seek;
        return 0;
    };
    resource->set_current_frame_handler = [](frame_index_t frame) {};
    buffering->set_all_writing_handler = [](frame_index_t frame) {};
    buffering->needs_all_writing_handler = [&called_needs_all_writing] {
        ++called_needs_all_writing;
        return false;
    };

    self->_cpp.rendering_handler(&buffer);

    XCTAssertEqual(called_pull_seek, 1);
    XCTAssertEqual(called_needs_all_writing, 1);
}

@end
