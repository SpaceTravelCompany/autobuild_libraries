# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) Contributors to the OpenEXR Project.

message(STATUS "Building OpenEXR libraries")

add_library(Imath STATIC IMPORTED)
set_target_properties(Imath PROPERTIES IMPORTED_LOCATION ${IMATH_LIB})
set_target_properties(Imath PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${IMATH_INCLUDE})

add_subdirectory( Iex )
add_subdirectory( IlmThread )

add_subdirectory( OpenEXRCore )
add_subdirectory( OpenEXR )
add_subdirectory( OpenEXRUtil )

