include_directories(../external/catch/single_include .)

set(HEADERS
    util/event_loop.hpp
    util/index_helpers.hpp
    util/templated_test_case.hpp
    util/test_file.hpp
)

set(SOURCES
    collection_change_indices.cpp
    index_set.cpp
    list.cpp
    main.cpp
    migrations.cpp
    object.cpp
    object_store.cpp
    primitive_list.cpp
    realm.cpp
    results.cpp
    schema.cpp
    thread_safe_reference.cpp
    transaction_log_parsing.cpp
    uuid.cpp

    util/event_loop.cpp
    util/test_file.cpp
)


if(REALM_ENABLE_SYNC)
    list(APPEND HEADERS
        sync/sync_test_utils.hpp
        sync/session/session_util.hpp
    )
    list(APPEND SOURCES
        sync/file.cpp
        sync/metadata.cpp
        sync/partial_sync.cpp
        sync/permission.cpp
        sync/session/connection_change_notifications.cpp
        sync/session/progress_notifications.cpp
        sync/session/session.cpp
        sync/session/wait_for_completion.cpp
        sync/sync_manager.cpp
        sync/sync_test_utils.cpp
        sync/user.cpp
    )
endif()

add_executable(tests ${SOURCES} ${HEADERS})
target_compile_definitions(tests PRIVATE ${PLATFORM_DEFINES})

if(REALM_ENABLE_SYNC)
    # It's necessary to explicitly link to realm-sync here to control the order in which libraries are
    # linked to avoid link errors when using GNU ld.
    target_link_libraries(tests realm-sync realm-sync-server realm-parser)
endif()

target_link_libraries(tests realm-object-store ${PLATFORM_LIBRARIES})
add_custom_command(TARGET tests POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_SOURCE_DIR}/sync-1.x.realm $<TARGET_FILE_DIR:tests>)

create_coverage_target(generate-coverage tests)

add_custom_target(run-tests USES_TERMINAL DEPENDS tests COMMAND ./tests)

add_subdirectory(notifications-fuzzer)
