# FindGLib.cmake
# © 2016 Evan Nemerson <evan@nemerson.com>
#
# CMake support for GLib/GObject/GIO.

find_package(PkgConfig)

if(PKG_CONFIG_FOUND)
  pkg_search_module(GLIB_PKG    glib-2.0)
  pkg_search_module(GOBJECT_PKG gobject-2.0)
  pkg_search_module(GIO_PKG     gio-2.0)
endif()

find_library(GLIB    glib-2.0    HINTS ${GLIB_PKG_LIBRARY_DIRS})
find_library(GOBJECT gobject-2.0 HINTS ${GOBJECT_PKG_LIBRARY_DIRS})
find_library(GIO     gio-2.0     HINTS ${GIO_PKG_LIBRARY_DIRS})

if(GLIB)
  add_library(glib-2.0 SHARED IMPORTED)
  set_property(TARGET glib-2.0 PROPERTY IMPORTED_LOCATION "${GLIB}")

  find_path(GLIB_INCLUDE_DIRS "glib.h"
    HINTS ${GLIB_PKG_INCLUDE_DIRS}
    PATH_SUFFIXES "glib-2.0")

  get_filename_component(GLIB_LIBDIR "${GLIB}" DIRECTORY)
  find_path(GLIB_CONFIG_INCLUDE_DIR "glibconfig.h"
    HINTS
      ${GLIB_LIBDIR}
      ${GLIB_PKG_INCLUDE_DIRS}
    PATHS
      "${CMAKE_LIBRARY_PATH}"
    PATH_SUFFIXES
      "glib-2.0/include"
      "glib-2.0")
  unset(GLIB_LIBDIR)

  if(NOT GLIB_CONFIG_INCLUDE_DIR)
    unset(GLIB_INCLUDE_DIRS)
  else()
    file(STRINGS "${GLIB_CONFIG_INCLUDE_DIR}/glibconfig.h" GLIB_MAJOR_VERSION REGEX "^#define GLIB_MAJOR_VERSION +([0-9]+)")
    string(REGEX REPLACE "^#define GLIB_MAJOR_VERSION ([0-9]+)$" "\\1" GLIB_MAJOR_VERSION "${GLIB_MAJOR_VERSION}")
    file(STRINGS "${GLIB_CONFIG_INCLUDE_DIR}/glibconfig.h" GLIB_MINOR_VERSION REGEX "^#define GLIB_MINOR_VERSION +([0-9]+)")
    string(REGEX REPLACE "^#define GLIB_MINOR_VERSION ([0-9]+)$" "\\1" GLIB_MINOR_VERSION "${GLIB_MINOR_VERSION}")
    file(STRINGS "${GLIB_CONFIG_INCLUDE_DIR}/glibconfig.h" GLIB_MICRO_VERSION REGEX "^#define GLIB_MICRO_VERSION +([0-9]+)")
    string(REGEX REPLACE "^#define GLIB_MICRO_VERSION ([0-9]+)$" "\\1" GLIB_MICRO_VERSION "${GLIB_MICRO_VERSION}")
    set(GLIB_VERSION "${GLIB_MAJOR_VERSION}.${GLIB_MINOR_VERSION}.${GLIB_MICRO_VERSION}")
    unset(GLIB_MAJOR_VERSION)
    unset(GLIB_MINOR_VERSION)
    unset(GLIB_MICRO_VERSION)

    list(APPEND GLIB_INCLUDE_DIRS ${GLIB_CONFIG_INCLUDE_DIR})
  endif()
endif()

if(GOBJECT)
  add_library(gobject-2.0 SHARED IMPORTED)
  set_property(TARGET gobject-2.0 PROPERTY IMPORTED_LOCATION "${GOBJECT}")

  find_path(GOBJECT_INCLUDE_DIRS "glib-object.h"
    HINTS ${GOBJECT_PKG_INCLUDE_DIRS}
    PATH_SUFFIXES "glib-2.0")
  if(GOBJECT_INCLUDE_DIRS)
    list(APPEND GOBJECT_INCLUDE_DIRS ${GLIB_INCLUDE_DIRS})
    list(REMOVE_DUPLICATES GOBJECT_INCLUDE_DIRS)
  endif()
endif()

if(GIO)
  add_library(gio-2.0 SHARED IMPORTED)
  set_property(TARGET gio-2.0 PROPERTY IMPORTED_LOCATION "${GIO}")

  find_path(GIO_INCLUDE_DIRS "gio/gio.h"
    HINTS ${GIO_PKG_INCLUDE_DIRS}
    PATH_SUFFIXES "glib-2.0")
  if(GIO_INCLUDE_DIRS)
    list(APPEND GIO_INCLUDE_DIRS ${GOBJECT_INCLUDE_DIRS})
    list(REMOVE_DUPLICATES GIO_INCLUDE_DIRS)
  endif()
endif()

find_program(GLIB_GENMARSHAL glib-genmarshal)
if(GLIB_GENMARSHAL)
  add_executable(glib-genmarshal IMPORTED)
  set_property(TARGET glib-genmarshal PROPERTY IMPORTED_LOCATION "${GLIB_GENMARSHAL}")
endif()

find_program(GLIB_MKENUMS glib-mkenums)
if(GLIB_MKENUMS)
  add_executable(glib-mkenums IMPORTED)
  set_property(TARGET glib-mkenums PROPERTY IMPORTED_LOCATION "${GLIB_MKENUMS}")
endif()

find_program(GLIB_COMPILE_SCHEMAS glib-compile-schemas)
if(GLIB_COMPILE_SCHEMAS)
  add_executable(glib-compile-schemas IMPORTED)
  set_property(TARGET glib-compile-schemas PROPERTY IMPORTED_LOCATION "${GLIB_COMPILE_SCHEMAS}")
endif()

find_program(GLIB_COMPILE_RESOURCES glib-compile-resources)
if(GLIB_COMPILE_RESOURCES)
  add_executable(glib-compile-resources IMPORTED)
  set_property(TARGET glib-compile-resources PROPERTY IMPORTED_LOCATION "${GLIB_COMPILE_RESOURCES}")
endif()

function(glib_compile_resources SPEC_FILE)
  set (options INTERNAL)
  set (oneValueArgs TARGET SOURCE_DIR HEADER SOURCE C_NAME)
  set (multiValueArgs)
  cmake_parse_arguments(GLIB_COMPILE_RESOURCES "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  unset (options)
  unset (oneValueArgs)
  unset (multiValueArgs)

  if(NOT GLIB_COMPILE_RESOURCES_SOURCE_DIR)
    set(GLIB_COMPILE_RESOURCES_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  set(FLAGS)

  if(GLIB_COMPILE_RESOURCES_INTERNAL)
    list(APPEND FLAGS "--internal")
  endif()

  if(GLIB_COMPILE_RESOURCES_C_NAME)
    list(APPEND FLAGS "--c-name" "${GLIB_COMPILE_RESOURCES_C_NAME}")
  endif()

  get_filename_component(SPEC_FILE "${SPEC_FILE}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

  execute_process(
    COMMAND glib-compile-resources
      --generate-dependencies
      --sourcedir "${GLIB_COMPILE_RESOURCES_SOURCE_DIR}"
      "${SPEC_FILE}"
    OUTPUT_VARIABLE deps
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  if(GLIB_COMPILE_RESOURCES_HEADER)
    get_filename_component(GLIB_COMPILE_RESOURCES_HEADER "${GLIB_COMPILE_RESOURCES_HEADER}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")

    add_custom_command(
      OUTPUT "${GLIB_COMPILE_RESOURCES_HEADER}"
      COMMAND glib-compile-resources
        --sourcedir "${GLIB_COMPILE_RESOURCES_SOURCE_DIR}"
        --generate-header
        --target "${GLIB_COMPILE_RESOURCES_HEADER}"
        ${FLAGS}
        "${SPEC_FILE}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()

  if(GLIB_COMPILE_RESOURCES_SOURCE)
    get_filename_component(GLIB_COMPILE_RESOURCES_SOURCE "${GLIB_COMPILE_RESOURCES_SOURCE}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")

    add_custom_command(
      OUTPUT "${GLIB_COMPILE_RESOURCES_SOURCE}"
      COMMAND glib-compile-resources
        --sourcedir "${GLIB_COMPILE_RESOURCES_SOURCE_DIR}"
        --generate-source
        --target "${GLIB_COMPILE_RESOURCES_SOURCE}"
        ${FLAGS}
        "${SPEC_FILE}"
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
endfunction()

find_program(GDBUS_CODEGEN gdbus-codegen)
if(GDBUS_CODEGEN)
  add_executable(gdbus-codegen IMPORTED)
  set_property(TARGET gdbus-codegen PROPERTY IMPORTED_LOCATION "${GDBUS_CODEGEN}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(GLib
    REQUIRED_VARS
      GLIB_INCLUDE_DIRS
      GOBJECT_INCLUDE_DIRS
      GIO_INCLUDE_DIRS
      GLIB_MKENUMS
      GLIB_GENMARSHAL
      GLIB_COMPILE_SCHEMAS
      GLIB_COMPILE_RESOURCES
      GDBUS_CODEGEN
    VERSION_VAR
      GLIB_VERSION)