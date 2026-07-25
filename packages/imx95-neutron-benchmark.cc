// SPDX-License-Identifier: MIT

#include <dlfcn.h>

#include <cstring>
#include <fstream>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include "tensorflow/lite/builtin_ops.h"
#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model_builder.h"

namespace {

using CreateDelegate = TfLiteDelegate* (*)(char**, char**, size_t,
                                            void (*)(const char*));
using DestroyDelegate = void (*)(TfLiteDelegate*);

struct Arguments {
  std::string delegate_path;
  std::string graph;
  std::string input;
  std::string output;
  std::string profile;
};

std::string Value(const std::string& argument, const std::string& name) {
  const std::string prefix = "--" + name + "=";
  if (argument.rfind(prefix, 0) == 0) {
    return argument.substr(prefix.size());
  }
  return {};
}

Arguments ParseArguments(int argc, char** argv) {
  Arguments result;
  for (int index = 1; index < argc; ++index) {
    const std::string argument(argv[index]);
    if (const auto value = Value(argument, "graph"); !value.empty()) {
      result.graph = value;
    } else if (const auto value = Value(argument, "external_delegate_path");
               !value.empty()) {
      result.delegate_path = value;
    } else if (const auto value = Value(argument, "input_layer_value_files");
               !value.empty()) {
      const auto separator = value.find(':');
      result.input =
          separator == std::string::npos ? value : value.substr(separator + 1);
    } else if (const auto value = Value(argument, "output_filepath");
               !value.empty()) {
      result.output = value;
    } else if (const auto value = Value(argument, "op_profiling_output_file");
               !value.empty()) {
      result.profile = value;
    }
  }
  return result;
}

std::vector<char> ReadFile(const std::string& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    return {};
  }
  return {std::istreambuf_iterator<char>(stream),
          std::istreambuf_iterator<char>()};
}

bool WriteFile(const std::string& path, const char* data, size_t size) {
  std::ofstream stream(path, std::ios::binary);
  stream.write(data, size);
  return stream.good();
}

void ReportDelegateError(const char* message) {
  std::cerr << "ERROR: external delegate: " << message << '\n';
}

}  // namespace

int main(int argc, char** argv) {
  const Arguments arguments = ParseArguments(argc, argv);
  if (arguments.graph.empty() || arguments.input.empty() ||
      arguments.output.empty()) {
    std::cerr << "ERROR: --graph, --input_layer_value_files, and "
                 "--output_filepath are required\n";
    return 2;
  }

  auto model = tflite::FlatBufferModel::BuildFromFile(arguments.graph.c_str());
  if (!model) {
    std::cerr << "ERROR: failed to load model\n";
    return 1;
  }

  tflite::ops::builtin::BuiltinOpResolver resolver;
  std::unique_ptr<tflite::Interpreter> interpreter;
  if (tflite::InterpreterBuilder(*model, resolver)(&interpreter) != kTfLiteOk ||
      !interpreter) {
    std::cerr << "ERROR: failed to build interpreter\n";
    return 1;
  }

  void* delegate_handle = nullptr;
  TfLiteDelegate* delegate = nullptr;
  DestroyDelegate destroy_delegate = nullptr;
  int delegated_nodes = 0;

  if (!arguments.delegate_path.empty()) {
    delegate_handle = dlopen(arguments.delegate_path.c_str(), RTLD_NOW);
    if (!delegate_handle) {
      std::cerr << "ERROR: failed to load external delegate: " << dlerror()
                << '\n';
      return 1;
    }

    auto create_delegate = reinterpret_cast<CreateDelegate>(
        dlsym(delegate_handle, "tflite_plugin_create_delegate"));
    destroy_delegate = reinterpret_cast<DestroyDelegate>(
        dlsym(delegate_handle, "tflite_plugin_destroy_delegate"));
    if (!create_delegate || !destroy_delegate) {
      std::cerr << "ERROR: external delegate plugin symbols are missing\n";
      dlclose(delegate_handle);
      return 1;
    }

    delegate = create_delegate(nullptr, nullptr, 0, ReportDelegateError);
    if (!delegate ||
        interpreter->ModifyGraphWithDelegate(delegate) != kTfLiteOk) {
      std::cerr << "ERROR: failed to apply external delegate\n";
      interpreter.reset();
      if (delegate) {
        destroy_delegate(delegate);
      }
      dlclose(delegate_handle);
      return 1;
    }

    for (const int node_index : interpreter->execution_plan()) {
      const auto* node = interpreter->node_and_registration(node_index);
      if (node && node->second.builtin_code == kTfLiteBuiltinDelegate) {
        ++delegated_nodes;
      }
    }
    std::cout << "INFO: " << delegated_nodes << " nodes delegated out of "
              << interpreter->nodes_size() << " nodes\n";
    if (delegated_nodes == 0) {
      std::cerr << "ERROR: external delegate produced no execution nodes\n";
      interpreter.reset();
      destroy_delegate(delegate);
      dlclose(delegate_handle);
      return 1;
    }
  }

  if (interpreter->AllocateTensors() != kTfLiteOk ||
      interpreter->inputs().size() != 1) {
    std::cerr << "ERROR: failed to allocate the single-input model\n";
    return 1;
  }

  const std::vector<char> input = ReadFile(arguments.input);
  TfLiteTensor* input_tensor = interpreter->tensor(interpreter->inputs()[0]);
  if (!input_tensor || input.size() != input_tensor->bytes) {
    std::cerr << "ERROR: input byte size does not match the model\n";
    return 1;
  }
  std::memcpy(input_tensor->data.raw, input.data(), input.size());

  if (interpreter->Invoke() != kTfLiteOk ||
      interpreter->Invoke() != kTfLiteOk || interpreter->outputs().empty()) {
    std::cerr << "ERROR: inference failed\n";
    return 1;
  }

  const TfLiteTensor* output_tensor =
      interpreter->tensor(interpreter->outputs()[0]);
  if (!output_tensor ||
      !WriteFile(arguments.output, output_tensor->data.raw,
                 output_tensor->bytes)) {
    std::cerr << "ERROR: failed to write inference output\n";
    return 1;
  }

  if (!arguments.profile.empty()) {
    std::ofstream profile(arguments.profile);
    profile << "delegate_execution_nodes\n" << delegated_nodes << '\n';
    if (!profile.good()) {
      std::cerr << "ERROR: failed to write delegate profile\n";
      return 1;
    }
  }

  interpreter.reset();
  if (delegate) {
    destroy_delegate(delegate);
    dlclose(delegate_handle);
  }
  return 0;
}
