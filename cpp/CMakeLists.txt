cmake_minimum_required(VERSION 3.14)
project(misarmail-cpp VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── Dependencies ─────────────────────────────────────────────────────────────

find_package(CURL REQUIRED)

# ── Library ──────────────────────────────────────────────────────────────────

add_library(misarmail
    src/client.cpp
)

target_include_directories(misarmail
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

target_link_libraries(misarmail PUBLIC CURL::libcurl)

# Strict warnings
target_compile_options(misarmail PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:
        -Wall -Wextra -Wpedantic -Werror>
)

# ── Tests ────────────────────────────────────────────────────────────────────

option(MISARMAIL_BUILD_TESTS "Build tests" ON)

if(MISARMAIL_BUILD_TESTS)
    enable_testing()

    add_executable(misarmail_tests tests/test_client.cpp)
    target_link_libraries(misarmail_tests PRIVATE misarmail)
    target_compile_options(misarmail_tests PRIVATE
        $<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall -Wextra>
    )

    add_test(NAME misarmail_tests COMMAND misarmail_tests)
endif()

# ── Install ──────────────────────────────────────────────────────────────────

include(GNUInstallDirs)

install(TARGETS misarmail
    EXPORT misarmailTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT misarmailTargets
    FILE misarmailTargets.cmake
    NAMESPACE misarmail::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/misarmail
)
