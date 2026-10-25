cmake_minimum_required(VERSION 3.16)
project(tsp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(tsp
    src/main.cpp
    src/instance.cpp
    src/algorithms.cpp
)
target_include_directories(tsp PRIVATE include)
