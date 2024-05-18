//
//  file_module.h
//

#pragma once

#include <audio-processing/module/maker/file_module_context.h>

namespace yas::proc {
namespace file {
    template <typename SampleType>
    [[nodiscard]] module_ptr make_signal_module(std::filesystem::path const &, frame_index_t const module_offset,
                                                frame_index_t const file_offset);
}  // namespace file
}  // namespace yas::proc
