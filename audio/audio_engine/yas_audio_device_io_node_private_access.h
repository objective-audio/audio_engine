//
//  yas_audio_device_io_node_private_access.h
//

#pragma once

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#if YAS_TEST

namespace yas {
namespace audio {
    class device_io_node::private_access {
       public:
    };
}
}

#endif
#endif
