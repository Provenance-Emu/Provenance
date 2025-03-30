// SPDX-FileCopyrightText: Copyright (c) 2022 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <cstddef>
#include <tuple>
#include <type_traits>

#include "oaknut/oaknut_exception.hpp"

namespace oaknut {

struct Elem;
template<typename>
struct ElemSelector;
struct VRegArranged;

namespace detail {

template<typename>
struct is_instance_of_ElemSelector : std::false_type {};

template<typename E>
struct is_instance_of_ElemSelector<ElemSelector<E>> : std::true_type {};

template<class T>
constexpr bool is_instance_of_ElemSelector_v = is_instance_of_ElemSelector<T>::value;

struct BaseOnlyTag {};

}  // namespace detail

template<typename T, std::size_t N>
struct List {
    template<typename... U>
    constexpr explicit List(U... args)
        : m_base(std::get<0>(std::tie(args...)))
    {
        static_assert((std::is_same_v<T, U> && ...));
        static_assert(sizeof...(args) == N);
        static_assert(std::is_base_of_v<VRegArranged, T> || std::is_base_of_v<Elem, T> || detail::is_instance_of_ElemSelector_v<T>);

        if (!verify(std::index_sequence_for<U...>{}, args...))
            throw OaknutException{ExceptionType::InvalidList};
    }

    constexpr auto operator[](unsigned elem_index) const
    {
        using S = decltype(m_base[elem_index]);
        return List<S, N>(detail::BaseOnlyTag{}, m_base[elem_index]);
    }

private:
    template<typename>
    friend class BasicCodeGenerator;
    template<typename, std::size_t>
    friend struct List;

    constexpr explicit List(detail::BaseOnlyTag, T base_)
        : m_base(base_)
    {}

    template<typename... U, std::size_t... indexes>
    constexpr bool verify(std::index_sequence<indexes...>, U... args)
    {
        if constexpr (std::is_base_of_v<VRegArranged, T>) {
            return (((m_base.index() + indexes) % 32 == static_cast<std::size_t>(args.index())) && ...);
        } else if constexpr (std::is_base_of_v<Elem, T>) {
            return (((m_base.reg_index() + indexes) % 32 == static_cast<std::size_t>(args.reg_index()) && m_base.elem_index() == args.elem_index()) && ...);
        } else {
            return (((m_base.reg_index() + indexes) % 32 == static_cast<std::size_t>(args.reg_index())) && ...);
        }
    }

    T m_base;
};

template<typename... U>
List(U...) -> List<std::common_type_t<U...>, sizeof...(U)>;

}  // namespace oaknut
