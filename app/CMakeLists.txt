find_package(Qt6 REQUIRED COMPONENTS Core Quick)
qt_standard_project_setup()

add_executable(MacCleanerApp
    main.cpp
    JunkModel.h
    JunkModel.cpp
    resources.qrc
)


set_target_properties(MacCleanerApp PROPERTIES
    WIN32_EXECUTABLE FALSE
)

target_include_directories(MacCleanerApp PRIVATE ${CMAKE_SOURCE_DIR}/core ${CMAKE_SOURCE_DIR}/mac)
target_link_libraries(MacCleanerApp PRIVATE core macbridge Qt6::Core Qt6::Quick)

# For QML resources: treat Main.qml as resource next step or load from file system.
# Simpler: the app loads QML via a local file path.
