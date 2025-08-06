# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

set(build_dependecy)
set(BUILD_ORDER_CONTENT)
foreach(target ${IMAGES})
  get_target_property(dependencies ${target} MANUALLY_ADDED_DEPENDENCIES)
  if(dependencies)
    set(build_dependecy "${build_dependecy} ${target}:${dependencies}")
  endif()
endforeach()

execute_process(
  COMMAND ${PYTHON_EXECUTABLE} ${SdkRootDirPath}/cmake/extension/sysbuild/scripts/build_order.py "${build_dependecy}" -o ${CMAKE_BINARY_DIR}/build_order.yaml
  RESULT_VARIABLE EXEC_RESULT
)

if((EXEC_RESULT STREQUAL 0) AND (EXISTS "${CMAKE_BINARY_DIR}/build_order.yaml"))
  # Read build order setting to BUILD_ORDER_CONTENT 
  file(READ "${CMAKE_BINARY_DIR}/build_order.yaml" BUILD_ORDER_CONTENT)
else()
  message(SEND_ERROR "Error occured when analysising building order.")
endif()


