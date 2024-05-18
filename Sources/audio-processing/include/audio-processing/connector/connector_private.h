//
//  connector_private.h
//

#pragma once

namespace yas::proc {
template <typename T, typename Enable = void>
struct enum_to_connector_index;

template <typename T>
struct enum_to_connector_index<T, typename std::enable_if_t<std::is_enum<T>::value>> {
    static connector_index_t to_index(T const &value) {
        return static_cast<connector_index_t>(value);
    }
};
}  // namespace yas::proc

template <typename T>
yas::proc::connector_index_t yas::proc::to_connector_index(T const &value) {
    return enum_to_connector_index<T>::to_index(value);
}
