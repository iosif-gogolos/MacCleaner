add_executable(test_scanner
    test_scanner.cpp
)

target_link_libraries(test_scanner PRIVATE core Qt6::Core)
