cmake_minimum_required(VERSION 3.14)
project(anysearch LANGUAGES CXX)

set(BINARY_NAME "anysearch")
set(APPLICATION_ID "com.anysearch.app")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

add_subdirectory(${FLUTTER_MANAGED_DIR})

add_subdirectory(runner)
