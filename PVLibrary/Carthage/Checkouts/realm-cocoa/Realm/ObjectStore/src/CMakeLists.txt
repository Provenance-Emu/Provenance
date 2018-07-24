set(SOURCES
    binding_callback_thread_observer.cpp
    collection_notifications.cpp
    index_set.cpp
    list.cpp
    object.cpp
    object_schema.cpp
    object_store.cpp
    results.cpp
    schema.cpp
    shared_realm.cpp
    thread_safe_reference.cpp

    impl/collection_change_builder.cpp
    impl/collection_notifier.cpp
    impl/list_notifier.cpp
    impl/object_notifier.cpp
    impl/primitive_list_notifier.cpp
    impl/realm_coordinator.cpp
    impl/results_notifier.cpp
    impl/transact_log_handler.cpp
    impl/weak_realm_notifier.cpp
    util/uuid.cpp)

set(HEADERS
    binding_callback_thread_observer.hpp
    collection_notifications.hpp
    execution_context_id.hpp
    feature_checks.hpp
    index_set.hpp
    list.hpp
    object.hpp
    object_accessor.hpp
    object_schema.hpp
    object_store.hpp
    property.hpp
    results.hpp
    schema.hpp
    shared_realm.hpp
    thread_safe_reference.hpp

    impl/apple/external_commit_helper.hpp
    impl/apple/keychain_helper.hpp
    impl/epoll/external_commit_helper.hpp
    impl/generic/external_commit_helper.hpp

    impl/collection_change_builder.hpp
    impl/collection_notifier.hpp
    impl/external_commit_helper.hpp
    impl/list_notifier.hpp
    impl/notification_wrapper.hpp
    impl/object_accessor_impl.hpp
    impl/object_notifier.hpp
    impl/primitive_list_notifier.hpp
    impl/realm_coordinator.hpp
    impl/results_notifier.hpp
    impl/transact_log_handler.hpp
    impl/weak_realm_notifier.hpp

    util/android/event_loop_signal.hpp
    util/apple/event_loop_signal.hpp
    util/generic/event_loop_signal.hpp
    util/uv/event_loop_signal.hpp

    util/aligned_union.hpp
    util/atomic_shared_ptr.hpp
    util/event_loop_signal.hpp
    util/tagged_bool.hpp
    util/time.hpp
    util/uuid.hpp)

if(APPLE)
    list(APPEND SOURCES impl/apple/external_commit_helper.cpp impl/apple/keychain_helper.cpp)
elseif(REALM_HAVE_EPOLL)
    list(APPEND SOURCES impl/epoll/external_commit_helper.cpp)
elseif(CMAKE_SYSTEM_NAME MATCHES "^Windows")
    list(APPEND SOURCES impl/windows/external_commit_helper.cpp)
else()
    list(APPEND SOURCES impl/generic/external_commit_helper.cpp)
endif()

if(NOT APPLE AND NOT REALM_PLATFORM STREQUAL "Android")
    list(APPEND SOURCES util/generic/event_loop_signal.cpp)
endif()

set(INCLUDE_DIRS
    ${PEGTL_INCLUDE_DIR}
    ${UV_INCLUDE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR})

if(REALM_ENABLE_SYNC)
    list(APPEND HEADERS
        sync/partial_sync.hpp
        sync/subscription_state.hpp
        sync/sync_config.hpp
        sync/sync_manager.hpp
        sync/sync_permission.hpp
        sync/sync_session.hpp
        sync/sync_user.hpp
        sync/impl/sync_client.hpp
        sync/impl/sync_file.hpp
        sync/impl/sync_metadata.hpp
        sync/impl/work_queue.hpp)
    list(APPEND SOURCES
        sync/partial_sync.cpp
        sync/sync_config.cpp
        sync/sync_manager.cpp
        sync/sync_permission.cpp
        sync/sync_session.cpp
        sync/sync_user.cpp
        sync/impl/sync_file.cpp
        sync/impl/sync_metadata.cpp
        sync/impl/work_queue.cpp)
    if(APPLE)
        list(APPEND SOURCES
            sync/impl/apple/network_reachability_observer.cpp
            sync/impl/apple/system_configuration.cpp)
    endif()
    find_package(ZLIB REQUIRED)
    list(APPEND INCLUDE_DIRS ${ZLIB_INCLUDE_DIRS})
endif()

add_library(realm-object-store STATIC ${SOURCES} ${HEADERS})
set_target_properties(realm-object-store PROPERTIES POSITION_INDEPENDENT_CODE 1)
target_compile_definitions(realm-object-store PRIVATE ${PLATFORM_DEFINES})
target_include_directories(realm-object-store PUBLIC ${INCLUDE_DIRS})
target_link_libraries(realm-object-store PUBLIC realm ${PLATFORM_LIBRARIES})

if(REALM_ENABLE_SYNC)
    # Add the sync libraries separately to reduce merge conflicts.
    target_link_libraries(realm-object-store PUBLIC realm-sync ${ZLIB_LIBRARIES})
endif()
