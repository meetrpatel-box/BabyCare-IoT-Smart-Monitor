// cry_gate_inference.cc — TFLite Micro wrapper around the int8 BinaryCryCNN.
// See cry_gate_inference.h for the public C API this implements.
//
// Op resolver: the exported model's op list was inspected directly from the
// .tflite flatbuffer (ML_pipeline_edge/edge_models/binary_cry_cnn_int8.tflite),
// NOT assumed — see ML_pipeline_edge/export/inspect ops in
// docs/ENGINEERING_DECISIONS.md. Sequence: CONV_2D, MAX_POOL_2D (x4 blocks),
// RESHAPE, GATHER_ND, TRANSPOSE, MEAN, RESHAPE, FULLY_CONNECTED (x2).
// GATHER_ND/TRANSPOSE/MEAN come from onnx2tf's lowering of PyTorch's
// AdaptiveAvgPool2d((4,4)) — not ESP-NN-accelerated (ESP-NN only speeds up
// conv2d/depthwise-conv/fully-connected/pooling), but the tensors at that
// point in the graph are small (128x4x4), so reference-kernel speed there is
// not expected to be a bottleneck. All 7 ops are registered in mainline
// tflite-micro's MicroMutableOpResolver (verified against
// tensorflow/tflite-micro's micro_mutable_op_resolver.h).
//
// Tensor arena: the model's first Conv2D produces a (1,128,431,32) int8
// activation ~1.76MB before the first MaxPool halves it — the arena MUST be
// PSRAM-backed (kTensorArenaSize below is a generous starting point, not a
// measured minimum; log the actual interpreter->arena_used_bytes() after a
// real build and shrink accordingly).

#include "cry_gate_inference.h"

#include <cmath>

#include "esp_err.h"
#include "esp_log.h"
#include "esp_heap_caps.h"

#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/micro_log.h"
#include "tensorflow/lite/schema/schema_generated.h"

#include "data/cry_gate_model_data.h"

static const char *TAG = "cry_gate_inference";

// Generous starting point — PSRAM is 8MB on this board (ESP32-S3R8), so this
// is not tight, but has not been measured against a real build. Log
// arena_used_bytes() (see cry_gate_inference_init) and shrink once known.
static constexpr size_t kTensorArenaSize = 2 * 1024 * 1024;
static constexpr int kNumOps = 7;  // CONV_2D, MAX_POOL_2D, RESHAPE, GATHER_ND, TRANSPOSE, MEAN, FULLY_CONNECTED

static uint8_t *s_tensor_arena = nullptr;
static const tflite::Model *s_model = nullptr;
static tflite::MicroInterpreter *s_interpreter = nullptr;
static TfLiteTensor *s_input = nullptr;
static TfLiteTensor *s_output = nullptr;
static bool s_initialized = false;

// Static storage for resolver + interpreter — TFLite Micro objects are not
// designed to be heap-allocated/destroyed, so these live for the process
// lifetime (matches the espressif/esp-tflite-micro examples' pattern).
static tflite::MicroMutableOpResolver<kNumOps> s_resolver;
alignas(16) static uint8_t s_interpreter_storage[sizeof(tflite::MicroInterpreter)];

int cry_gate_inference_init(void) {
    if (s_initialized) {
        return 0;
    }

    s_model = tflite::GetModel(g_cry_gate_model);
    if (s_model->version() != TFLITE_SCHEMA_VERSION) {
        ESP_LOGE(TAG, "Model schema version %lu != supported %d",
                 (unsigned long)s_model->version(), TFLITE_SCHEMA_VERSION);
        return -1;
    }

    if (s_resolver.AddConv2D() != kTfLiteOk ||
        s_resolver.AddMaxPool2D() != kTfLiteOk ||
        s_resolver.AddReshape() != kTfLiteOk ||
        s_resolver.AddGatherNd() != kTfLiteOk ||
        s_resolver.AddTranspose() != kTfLiteOk ||
        s_resolver.AddMean() != kTfLiteOk ||
        s_resolver.AddFullyConnected() != kTfLiteOk) {
        ESP_LOGE(TAG, "Failed to register one or more ops with the resolver");
        return -1;
    }

    s_tensor_arena = (uint8_t *)heap_caps_malloc(
        kTensorArenaSize, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (s_tensor_arena == nullptr) {
        ESP_LOGE(TAG, "Failed to allocate %u-byte tensor arena in PSRAM — "
                      "is CONFIG_SPIRAM enabled?", (unsigned)kTensorArenaSize);
        return -1;
    }

    s_interpreter = new (s_interpreter_storage) tflite::MicroInterpreter(
        s_model, s_resolver, s_tensor_arena, kTensorArenaSize);

    TfLiteStatus alloc_status = s_interpreter->AllocateTensors();
    if (alloc_status != kTfLiteOk) {
        ESP_LOGE(TAG, "AllocateTensors() failed — arena too small "
                      "(kTensorArenaSize=%u)", (unsigned)kTensorArenaSize);
        return -1;
    }
    ESP_LOGI(TAG, "Tensor arena: %u bytes used of %u allocated",
             (unsigned)s_interpreter->arena_used_bytes(), (unsigned)kTensorArenaSize);

    s_input = s_interpreter->input(0);
    s_output = s_interpreter->output(0);

    if (s_input->type != kTfLiteInt8 || s_output->type != kTfLiteInt8) {
        ESP_LOGE(TAG, "Expected int8 input/output tensors (got input=%d output=%d)",
                 (int)s_input->type, (int)s_output->type);
        return -1;
    }
    const int expected_input_elems = CRY_GATE_N_MEL * CRY_GATE_TARGET_T;
    if (s_input->bytes != (size_t)expected_input_elems) {
        ESP_LOGE(TAG, "Input tensor size mismatch: got %u bytes, expected %d",
                 (unsigned)s_input->bytes, expected_input_elems);
        return -1;
    }

    s_initialized = true;
    ESP_LOGI(TAG, "cry_gate_inference initialized "
                  "(input scale=%.6f zero=%d, output scale=%.6f zero=%d)",
             s_input->params.scale, s_input->params.zero_point,
             s_output->params.scale, s_output->params.zero_point);
    return 0;
}

float cry_gate_inference_run(const mel_features_t *features) {
    if (!s_initialized) {
        ESP_LOGE(TAG, "cry_gate_inference_init() was not called");
        return -1.0f;
    }

    // Quantize: features->data is already the normalized (128, 431) log-mel
    // array in row-major [mel][time] order, matching the model's expected
    // NHWC (1, 128, 431, 1) layout exactly (channel dim is trivially 1, so
    // no reordering is needed — a direct element-wise copy).
    const float in_scale = s_input->params.scale;
    const int in_zero = s_input->params.zero_point;
    const int n_elems = CRY_GATE_N_MEL * CRY_GATE_TARGET_T;
    int8_t *in_data = s_input->data.int8;

    for (int i = 0; i < n_elems; i++) {
        int32_t q = (int32_t)lrintf(features->data[i] / in_scale) + in_zero;
        if (q < -128) q = -128;
        if (q > 127) q = 127;
        in_data[i] = (int8_t)q;
    }

    TfLiteStatus invoke_status = s_interpreter->Invoke();
    if (invoke_status != kTfLiteOk) {
        ESP_LOGE(TAG, "Invoke() failed");
        return -1.0f;
    }

    // Dequantize the raw logit, then apply sigmoid here — the exported
    // model's op list ends at FULLY_CONNECTED (see export_manifest.json),
    // matching export/validate_parity.py's post-processing exactly.
    const float out_scale = s_output->params.scale;
    const int out_zero = s_output->params.zero_point;
    int8_t out_q = s_output->data.int8[0];
    float logit = (float)(out_q - out_zero) * out_scale;
    float prob = 1.0f / (1.0f + expf(-logit));
    return prob;
}
