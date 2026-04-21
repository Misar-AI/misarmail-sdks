cmake_minimum_required(VERSION 3.14)
project(misarmail C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# ── Dependencies ─────────────────────────────────────────────────────────────
find_package(CURL REQUIRED)

# ── Library ──────────────────────────────────────────────────────────────────
add_library(misarmail STATIC src/misarmail.c)

target_include_directories(misarmail
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

target_link_libraries(misarmail PUBLIC CURL::libcurl)

# Strict warnings
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(misarmail PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ── Tests ────────────────────────────────────────────────────────────────────
enable_testing()

add_executable(misarmail_tests tests/test_misarmail.c)
target_link_libraries(misarmail_tests PRIVATE misarmail)

add_test(NAME misarmail_tests COMMAND misarmail_tests)

# ── Install ──────────────────────────────────────────────────────────────────
install(TARGETS misarmail
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)
install(FILES include/misarmail.h DESTINATION include)
