# CMakeLists.txt for HarmonyDesk Native Module
cmake_minimum_required(VERSION 3.5)
project(harmonydesk)

# 预编译的库路径
set(LIBRARY_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../libs/arm64-v8a)

# 创建一个空的 C++ 文件用于触发 CMake 构建
add_library(harmonydesk SHARED dummy.cpp)

# 复制预编译的 Rust 库到输出目录
add_custom_command(TARGET harmonydesk POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
        ${LIBRARY_DIR}/libharmonydesk.so
        ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libharmonydesk.so
    COMMENT "Copying libharmonydesk.so to output directory"
)

# 链接必要的系统库
target_link_libraries(harmonydesk PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
)
