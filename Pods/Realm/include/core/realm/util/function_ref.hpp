/*************************************************************************
 *
 * Copyright 2019 Realm Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 **************************************************************************/

#ifndef REALM_UTIL_FUNCTION_REF_HPP
#define REALM_UTIL_FUNCTION_REF_HPP

#include <functional>
#include <utility>

namespace realm {
namespace util {

/// A lightweight non-owning reference to a callable.
///
/// This type is similar to std::function, but unlike std::function holds a reference to the callable rather than
/// making a copy of it. This means that it will never require a heap allocation, and produces significantly smaller
/// binaries due to the template machinery being much simpler. This type should only ever be used as a function
/// parameter that is not stored past when the function returns. All other uses (including trying to store it in a
/// std::function) are very unlikely to be correct.
///
/// This implements a subset of P0792R5, which hopefully will be incorportated into a future version of the standard
/// library.
template <typename Signature>
class FunctionRef;
template <typename Return, typename... Args>
class FunctionRef<Return(Args...)> {
public:
    // A FunctionRef is never empty, and so cannot be default-constructed.
    constexpr FunctionRef() noexcept = delete;

    // FunctionRef is copyable and moveable.
#if defined(__GNUC__) && __GNUC__ == 4 && __GNUC_MINOR__ <= 9 && !defined(__clang__)
    FunctionRef(FunctionRef<Return(Args...)> const&) noexcept = default;
    FunctionRef<Return(Args...)>& operator=(const FunctionRef<Return(Args...)>&) noexcept = default;
    FunctionRef(FunctionRef<Return(Args...)>&&) noexcept = default;
    FunctionRef<Return(Args...)>& operator=(FunctionRef<Return(Args...)>&&) noexcept = default;
#else
    constexpr FunctionRef(FunctionRef<Return(Args...)> const&) noexcept = default;
    constexpr FunctionRef<Return(Args...)>& operator=(const FunctionRef<Return(Args...)>&) noexcept = default;
    constexpr FunctionRef(FunctionRef<Return(Args...)>&&) noexcept = default;
    constexpr FunctionRef<Return(Args...)>& operator=(FunctionRef<Return(Args...)>&&) noexcept = default;
#endif

    // Construct a FunctionRef which wraps the given callable.
    template <typename F>
    constexpr FunctionRef(F&& f) noexcept
        : m_obj(const_cast<void*>(reinterpret_cast<const void*>(std::addressof(f))))
        , m_callback([](void* obj, Args... args) -> Return {
            return (*reinterpret_cast<typename std::add_pointer<F>::type>(obj))(std::forward<Args>(args)...);
        })
    {
    }

    constexpr void swap(FunctionRef<Return(Args...)>& rhs) noexcept
    {
        std::swap(m_obj, rhs.m_obj);
        std::swap(m_callback, rhs.m_callback);
    }

    Return operator()(Args... args) const
    {
        return m_callback(m_obj, std::forward<Args>(args)...);
    }

private:
    void* m_obj;
    Return (*m_callback)(void*, Args...);
};

template <typename R, typename... Args>
constexpr void swap(FunctionRef<R(Args...)>& lhs, FunctionRef<R(Args...)>& rhs) noexcept
{
    lhs.swap(rhs);
}

} // namespace util
} // namespace realm

#endif
