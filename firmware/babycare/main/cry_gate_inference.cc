// cry_gate_inference.cc — TFLite Micro wrapper around the int8 BinaryCryCNN
// (native-16kHz edge16k checkpoint -- see
// ML_pipeline_edge/training/scripts/stage_binary_cry_gate_edge16k.py).
//
// Op resolver: the exported model's op list was inspected directly from the
// .tflite flatbuffer (edge_models/edge16k/binary_cry_cnn_edge16k_int8.tflite,
// via export_to_tflite_edge16k.py's _check_no_gather_nd(), which fails the
// export outright if this ever regresses) -- NOT assumed. Real output:
// ['CONV_2D', 'FULLY_CONNECTED', 'MAX_POOL_2D', 'MEAN']. This is the FIXED
// architecture -- the previous checkpoint's nn.AdaptiveAvgPool2d((4,4)) (a
// non-integer input/output ratio against the conv stack's output width)
// forced PyTorch's ONNX exporter into a dynamic index-gather graph, which
// onnx2tf lowered to GATHER_ND with int64 indices -- unsupported by TFLite
// Micro's reference kernel (confirmed on real ESP32-S3 hardware: "Indices
// of type 'INT64' are not supported by gather_nd"). Replacing it with
// nn.AdaptiveAvgPool2d((1,1)) (global average pooling) eliminates that
// entirely -- PyTorch/onnx2tf lower it to a plain MEAN reduction for any
// input size, no GATHER_ND/TRANSPOSE/RESHAPE anywhere in the graph. All 4
// ops are registered in mainline tflite-micro's MicroMutableOpResolver.
//
// Tensor arena: this is a genuinely smaller model than the previous
// checkpoint (273,889 params vs. 765,409 -- the (1,1) pooling head shrinks
// the classifier from Linear(2048,256) to Linear(128,256)), so
// kTensorArenaSize below is if anything MORE generous than needed; still
// unmeasured against a real build -- log arena_used_bytes() and shrink
// accordingly once known.

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
static constexpr int kNumOps = 4;  // CONV_2D, MAX_POOL_2D, MEAN, FULLY_CONNECTED

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
             s_input->params.scale, (int)s_input->params.zero_point,
             s_output->params.scale, (int)s_output->params.zero_point);
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
