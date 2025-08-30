find_package(Qt6 REQUIRED COMPONENTS Core)

qt_add_library(core STATIC
    Scanner.cpp
    Scanner.h
)

target_link_libraries(core PUBLIC Qt6::Core)
target_include_directories(core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
