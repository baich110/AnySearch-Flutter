cmake_minimum_required(VERSION 3.14)
project(anysearch LANGUAGES CXX)

set(BINARY_NAME "anysearch")
set(APPLICATION_ID "com.anysearch.app")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../flutter/windows)

add_subdirectory(runner)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${WINDOWS_BUNDLE_DIR}"
  BUNDLE DESTINATION .
  LIBRARY DESTINATION "${WINDOWS_BUNDLE_DIR}"
)
