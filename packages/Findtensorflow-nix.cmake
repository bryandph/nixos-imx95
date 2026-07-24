if(NOT DEFINED TFLITE_SOURCE_DIR)
  message(FATAL_ERROR "TFLITE_SOURCE_DIR is required")
endif()
if(NOT DEFINED TFLITE_LIB_LOC)
  message(FATAL_ERROR "TFLITE_LIB_LOC is required")
endif()
if(NOT DEFINED TFLITE_INCLUDE_DIR)
  message(FATAL_ERROR "TFLITE_INCLUDE_DIR is required")
endif()

add_library(TensorFlow::tensorflow-lite SHARED IMPORTED)
set_target_properties(
  TensorFlow::tensorflow-lite
  PROPERTIES
    IMPORTED_LOCATION "${TFLITE_LIB_LOC}"
    INTERFACE_INCLUDE_DIRECTORIES "${TFLITE_INCLUDE_DIR}"
)

list(APPEND NEUTRON_DELEGATE_DEPENDENCIES TensorFlow::tensorflow-lite)
list(APPEND NEUTRON_DELEGATE_SRCS
  "${TFLITE_SOURCE_DIR}/tools/command_line_flags.cc"
)
