//
//  yas_audio_device_io_node_protocol.h
//

#pragma once

namespace yas {
namespace audio {
    class device_io;

    class manageable_device_io_node {
       public:
        virtual ~manageable_device_io_node() = default;

        virtual void _add_device_io() = 0;
        virtual void _remove_device_io() = 0;
        virtual audio::device_io &_device_io() const = 0;
    };
}
}
