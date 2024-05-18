//
//  player_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>
#import "player_test_utils.h"

using namespace yas;
using namespace yas::playing;

@interface player_tests : XCTestCase

@end

@implementation player_tests {
    player_test::cpp _cpp;
}

- (void)tearDown {
    self->_cpp.reset();
}

- (void)test_constructor {
    player_task_priority const priority{.setup = 100, .rendering = 101};
    auto const worker = worker::make_shared();
    auto const renderer = std::make_shared<player_test::renderer>();
    auto const reading = std::make_shared<player_test::reading>();
    auto const buffering = std::make_shared<player_test::buffering>();
    auto const resource = std::make_shared<player_test::resource>(reading, buffering);

    std::vector<std::string> called_set_identifier;
    std::vector<channel_mapping> called_set_ch_mapping;
    std::vector<bool> called_set_is_playing;
    std::vector<renderer_rendering_f> called_set_rendering_handler;
    std::vector<std::string> called_set_identifier_request_handler;
    std::vector<channel_mapping> called_set_ch_mapping_request_handler;

    resource->set_playing_handler = [&called_set_is_playing](bool is_playing) {
        called_set_is_playing.emplace_back(is_playing);
    };

    renderer->set_rendering_handler_handler = [&called_set_rendering_handler](renderer_rendering_f &&handler) {
        called_set_rendering_handler.emplace_back(std::move(handler));
    };

    buffering->set_identifier_request_handler = [&called_set_identifier_request_handler](std::string identifier) {
        called_set_identifier_request_handler.emplace_back(identifier);
    };

    buffering->set_ch_mapping_request_handler = [&called_set_ch_mapping_request_handler](channel_mapping ch_mapping) {
        called_set_ch_mapping_request_handler.emplace_back(ch_mapping);
    };

    auto const player = player::make_shared(test_utils::root_path(), renderer, worker, priority, resource);

    XCTAssertEqual(called_set_is_playing.size(), 1);
    XCTAssertFalse(called_set_is_playing.at(0));
    XCTAssertEqual(called_set_rendering_handler.size(), 1);
    XCTAssertEqual(called_set_identifier_request_handler.size(), 1);
    XCTAssertEqual(called_set_identifier_request_handler.at(0), "");
    XCTAssertEqual(called_set_ch_mapping_request_handler.size(), 1);
    XCTAssertEqual(called_set_ch_mapping_request_handler.at(0).indices, (std::vector<channel_index_t>{}));
}

- (void)test_is_playing {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    XCTAssertFalse(player->is_playing());

    observing::canceller_pool pool;
    std::vector<bool> called_observing;

    player
        ->observe_is_playing([&called_observing](bool const &is_playing) { called_observing.emplace_back(is_playing); })
        .sync()
        ->add_to(pool);

    XCTAssertEqual(called_observing.size(), 1);
    XCTAssertFalse(called_observing.at(0));

    std::vector<bool> called_rendering;

    self->_cpp.resource->set_playing_handler = [&called_rendering](bool is_playing) {
        called_rendering.emplace_back(is_playing);
    };

    // is_playingにtrueがセットされる

    player->set_playing(true);

    XCTAssertTrue(player->is_playing());
    XCTAssertEqual(called_observing.size(), 2);
    XCTAssertTrue(called_observing.at(1));
    XCTAssertEqual(called_rendering.size(), 1);
    XCTAssertTrue(called_rendering.at(0));

    // is_playingに同じ値がセットされる

    player->set_playing(true);

    XCTAssertEqual(called_observing.size(), 2);
    XCTAssertEqual(called_rendering.size(), 1);

    // is_playingにfalseがセットされる

    player->set_playing(false);

    XCTAssertFalse(player->is_playing());
    XCTAssertEqual(called_observing.size(), 3);
    XCTAssertFalse(called_observing.at(2));
    XCTAssertEqual(called_rendering.size(), 2);
    XCTAssertFalse(called_rendering.at(1));
}

- (void)test_seek {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    std::vector<frame_index_t> called_seek;

    self->_cpp.resource->seek_handler = [&called_seek](frame_index_t frame_idx) {
        called_seek.emplace_back(frame_idx);
    };

    player->seek(100);

    XCTAssertEqual(called_seek.size(), 1);
    XCTAssertEqual(called_seek.at(0), 100);
}

- (void)test_is_seeking {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    bool is_seeking = false;

    self->_cpp.resource->is_seeking_handler = [&is_seeking] { return is_seeking; };

    XCTAssertFalse(player->is_seeking());

    is_seeking = true;

    XCTAssertTrue(player->is_seeking());
}

- (void)test_overwrite {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    std::vector<element_address> called_add_overwrite;

    self->_cpp.resource->add_overwrite_request_handler = [&called_add_overwrite](element_address &&address) {
        called_add_overwrite.emplace_back(address);
    };

    player->overwrite(3, {4, 1});

    XCTAssertEqual(called_add_overwrite.size(), 1);
    XCTAssertEqual(called_add_overwrite.at(0).file_channel_index, 3);
    XCTAssertEqual(called_add_overwrite.at(0).fragment_range.index, 4);
    XCTAssertEqual(called_add_overwrite.at(0).fragment_range.length, 1);

    player->overwrite(std::nullopt, {5, 2});

    XCTAssertEqual(called_add_overwrite.size(), 2);
    XCTAssertFalse(called_add_overwrite.at(1).file_channel_index.has_value());
    XCTAssertEqual(called_add_overwrite.at(1).fragment_range.index, 5);
    XCTAssertEqual(called_add_overwrite.at(1).fragment_range.length, 2);
}

- (void)test_current_frame {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    frame_index_t frame = 0;

    self->_cpp.resource->current_frame_handler = [&frame] { return frame; };

    XCTAssertEqual(player->current_frame(), 0);

    frame = 1;

    XCTAssertEqual(player->current_frame(), 1);
}

- (void)test_identifier {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    std::vector<std::string> called_set_identifier;

    self->_cpp.buffering->set_identifier_request_handler = [&called_set_identifier](std::string identifier) {
        called_set_identifier.emplace_back(identifier);
    };

    XCTAssertEqual(player->identifier(), "");

    player->set_identifier("555");

    XCTAssertEqual(player->identifier(), "555");
    XCTAssertEqual(called_set_identifier.size(), 1);
    XCTAssertEqual(called_set_identifier.at(0), "555");
}

- (void)test_ch_mapping {
    self->_cpp.setup_initial();

    auto const &player = self->_cpp.player;

    std::vector<channel_mapping> called_ch_mapping;

    self->_cpp.buffering->set_ch_mapping_request_handler = [&called_ch_mapping](channel_mapping ch_mapping) {
        called_ch_mapping.emplace_back(ch_mapping);
    };

    XCTAssertEqual(player->channel_mapping().indices, (std::vector<channel_index_t>{}));

    player->set_channel_mapping(channel_mapping{.indices = {1, 2, 3}});

    XCTAssertEqual(player->channel_mapping().indices, (std::vector<channel_index_t>{1, 2, 3}));
    XCTAssertEqual(called_ch_mapping.size(), 1);
    XCTAssertEqual(called_ch_mapping.at(0).indices, (std::vector<channel_index_t>{1, 2, 3}));
}

@end
