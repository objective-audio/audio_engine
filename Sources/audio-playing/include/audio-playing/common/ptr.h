//
//  yas_playing_ptr.h
//

#pragma once

#include <memory>

namespace yas::playing {
class exporter;
class exporter_resource;
class timeline_container;
class timeline_canceller;
class cancel_id;
class coordinator;
class renderer;
class player;
class buffering_resource;
class buffering_channel;
class buffering_element;
class reading_resource;
class player_resource;

class player_for_coordinator;
class renderer_for_coordinator;
class buffering_element_for_buffering_channel;
class buffering_channel_for_buffering_resource;
class buffering_resource_for_player_resource;
class reading_resource_for_player_resource;
class player_resource_for_player;
class exporter_for_coordinator;

using exporter_ptr = std::shared_ptr<exporter>;
using exporter_resource_ptr = std::shared_ptr<exporter_resource>;
using timeline_container_ptr = std::shared_ptr<timeline_container>;
using coordinator_ptr = std::shared_ptr<coordinator>;
using timeline_cancel_matcher_ptr = std::shared_ptr<timeline_canceller>;
using renderer_ptr = std::shared_ptr<renderer>;
using player_ptr = std::shared_ptr<player>;
using cancel_id_ptr = std::shared_ptr<cancel_id>;
using buffering_resource_ptr = std::shared_ptr<buffering_resource>;
using buffering_channel_ptr = std::shared_ptr<buffering_channel>;
using buffering_element_ptr = std::shared_ptr<buffering_element>;
using reading_resource_ptr = std::shared_ptr<reading_resource>;
using player_resource_ptr = std::shared_ptr<player_resource>;
}  // namespace yas::playing
