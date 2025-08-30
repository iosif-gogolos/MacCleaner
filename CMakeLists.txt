cmake_minimum_required(VERSION 3.16)
project(MacCleaner LANGUAGES CXX OBJCXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Make sure Qt6 is found by whoever builds this.
find_package(Qt6 REQUIRED COMPONENTS Core Quick Widgets) # Quick optional, Widgets for QApplication

add_subdirectory(core)
add_subdirectory(mac)
add_subdirectory(app)
add_subdirectory(tests)
