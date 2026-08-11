cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

define_property(GLOBAL PROPERTY RUNNER_RUNTIME_DEPENDENCIES)

set(BINARY_NAME "anysearch")
set(APPLICATION_ID "com.anysearch.app")

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.exe.manifest"
  "Runner.rc"
)

apply_standard_settings(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
iself_target_is_msvc(${BINARY_NAME})

add_dependencies(${BINARY_NAME} flutter_assemble)
