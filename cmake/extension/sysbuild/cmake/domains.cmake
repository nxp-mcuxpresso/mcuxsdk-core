# Copyright (c) 2021 Nordic Semiconductor
# Copyright 2025 NXP
#
# SPDX-License-Identifier: Apache-2.0

sysbuild_images_order(IMAGES_FLASHING_ORDER FLASH IMAGES ${IMAGES})

set(domains_yaml "default: ${DEFAULT_IMAGE}")
set(domains_yaml "${domains_yaml}\nbuild_dir: ${CMAKE_BINARY_DIR}")
set(domains_yaml "${domains_yaml}\ndomains:")
foreach(image ${IMAGES})
  set(domains_yaml "${domains_yaml}\n  - name: ${image}")
  set(domains_yaml "${domains_yaml}\n    build_dir: $<TARGET_PROPERTY:${image},_EP_BINARY_DIR>")
  set(domains_yaml "${domains_yaml}\n    source_dir: $<TARGET_PROPERTY:${image},_EP_SOURCE_DIR>")
endforeach()
set(domains_yaml "${domains_yaml}\nflash_order:")
foreach(image ${IMAGES_FLASHING_ORDER})
  set(flash_cond "$<NOT:$<BOOL:$<TARGET_PROPERTY:${image},BUILD_ONLY>>>")
  set(domains_yaml "${domains_yaml}$<${flash_cond}:\n  - ${image}>")
endforeach()
set(domains_yaml "${domains_yaml}\n${BUILD_ORDER_CONTENT}")

set(domains_yaml "${domains_yaml}\nname_mapping:")
foreach(image ${IMAGES})
  if(TARGET ${image}_cache)
    get_property(tmp_name TARGET ${image}_cache PROPERTY CMAKE_PROJECT_NAME)
    set(domains_yaml "${domains_yaml}\n  ${image}: ${tmp_name}")
  else()
    message(WARNING
    "domains.yaml:name_mapping: CMAKE_PROJECT_NAME is not found in CMakeCache.txt, use image name instead."
    )
    set(domains_yaml "${domains_yaml}\n  ${image}: ${image}")
  endif()
endforeach()

file(GENERATE OUTPUT ${CMAKE_BINARY_DIR}/domains.yaml CONTENT "${domains_yaml}")