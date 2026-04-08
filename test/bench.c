#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "nv12_crop.h"

#define WARMUP_ITERS   10
#define BENCH_ITERS    1000
#define SRC_W          1920
#define SRC_H          1080
#define CROP_X         0
#define CROP_Y         0
#define CROP_W         1280
#define CROP_H         720

static double get_time_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main(void)
{
    const int src_stride = SRC_W;
    const int dst_stride = CROP_W;
    const size_t src_size = (size_t)SRC_W * SRC_H * 3 / 2;
    const size_t dst_size = (size_t)CROP_W * CROP_H * 3 / 2;

    /* 分配源和目标缓冲区 */
    uint8_t *src = aligned_alloc(64, src_size);
    uint8_t *dst = aligned_alloc(64, dst_size);
    if (!src || !dst) {
        fprintf(stderr, "Failed to allocate buffers\n");
        return 1;
    }

    /* 填充源数据 */
    srand(42);
    for (size_t i = 0; i < src_size; i++)
        src[i] = (uint8_t)(rand() % 256);

    nv12_image_t src_info = {
        .width = SRC_W,
        .height = SRC_H,
        .src_stride = src_stride
    };

    /* 预热 */
    for (int i = 0; i < WARMUP_ITERS; i++) {
        nv12_crop(src, &src_info, dst, dst_stride, CROP_X, CROP_Y, CROP_W, CROP_H);
    }

    /* 基准测试 */
    double total_ns = 0.0;
    double min_ns = 1e18;
    double max_ns = 0.0;

    for (int i = 0; i < BENCH_ITERS; i++) {
        double t0 = get_time_ns();
        nv12_crop(src, &src_info, dst, dst_stride, CROP_X, CROP_Y, CROP_W, CROP_H);
        double t1 = get_time_ns();
        double elapsed = t1 - t0;
        total_ns += elapsed;
        if (elapsed < min_ns) min_ns = elapsed;
        if (elapsed > max_ns) max_ns = elapsed;
    }

    double avg_ns = total_ns / BENCH_ITERS;
    double data_mb = (double)dst_size / (1024.0 * 1024.0);
    double bandwidth = data_mb / (avg_ns / 1e9) / 1024.0; /* GB/s */

    printf("=== NV12 Crop Benchmark ===\n");
    printf("Source: %dx%d, Crop: (%d,%d) %dx%d\n",
           SRC_W, SRC_H, CROP_X, CROP_Y, CROP_W, CROP_H);
    printf("Iterations: %d (warmup: %d)\n", BENCH_ITERS, WARMUP_ITERS);
    printf("Output data: %.2f MB (%zu bytes)\n", data_mb, dst_size);
    printf("--- Results ---\n");
    printf("avg_ns/op:    %.1f\n", avg_ns);
    printf("min_ns/op:    %.1f\n", min_ns);
    printf("max_ns/op:    %.1f\n", max_ns);
    printf("bandwidth_GB/s: %.2f\n", bandwidth);

    free(src);
    free(dst);
    return 0;
}
