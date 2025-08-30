# Objective-C++ file to move files to Trash on macOS
add_library(macbridge STATIC
    Trash.mm
)

target_include_directories(macbridge PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
# link frameworks
find_library(COCOA_FRAMEWORK Cocoa)
find_library(FOUNDATION_FRAMEWORK Foundation)
target_link_libraries(macbridge PUBLIC ${COCOA_FRAMEWORK} ${FOUNDATION_FRAMEWORK})
