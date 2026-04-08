#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "nv12_crop.h"

#define SRC_W  64
#define SRC_H  48
#define CROP_X 8
#define CROP_Y 8
#define CROP_W 32
#define CROP_H 24

int main(void)
{
    const int src_stride = SRC_W;
    const int dst_stride = CROP_W;
    const size_t src_size = (size_t)SRC_W * SRC_H * 3 / 2;
    const size_t dst_size = (size_t)CROP_W * CROP_H * 3 / 2;

    uint8_t *src = (uint8_t *)malloc(src_size);
    uint8_t *dst = (uint8_t *)malloc(dst_size);

    if (!src || !dst) {
        fprintf(stderr, "Failed to allocate buffers\n");
        return 1;
    }

    /* 填充源数据: 用位置相关的模式 */
    for (size_t i = 0; i < src_size; i++)
        src[i] = (uint8_t)(i & 0xFF);

    nv12_image_t src_info = { .width = SRC_W, .height = SRC_H, .src_stride = src_stride };

    /* 执行 crop */
    nv12_crop(src, &src_info, dst, dst_stride, CROP_X, CROP_Y, CROP_W, CROP_H);

    /* 验证 Y 平面 */
    int errors = 0;
    for (int row = 0; row < CROP_H; row++) {
        for (int col = 0; col < CROP_W; col++) {
            uint8_t expected = src[(size_t)(CROP_Y + row) * src_stride + (CROP_X + col)];
            uint8_t actual = dst[(size_t)row * dst_stride + col];
            if (expected != actual) {
                if (errors < 10)
                    printf("Y mismatch at (%d,%d): expected 0x%02x, got 0x%02x\n",
                           col, row, expected, actual);
                errors++;
            }
        }
    }

    /* 验证 UV 平面 */
    int uv_crop_y = CROP_Y / 2;
    int uv_crop_h = CROP_H / 2;
    const uint8_t *src_uv_base = src + (size_t)src_stride * SRC_H;
    uint8_t *dst_uv_base = dst + (size_t)dst_stride * CROP_H;

    for (int row = 0; row < uv_crop_h; row++) {
        for (int col = 0; col < CROP_W; col++) {
            uint8_t expected = src_uv_base[(size_t)(uv_crop_y + row) * src_stride + CROP_X + col];
            uint8_t actual = dst_uv_base[(size_t)row * dst_stride + col];
            if (expected != actual) {
                if (errors < 10)
                    printf("UV mismatch at (%d,%d): expected 0x%02x, got 0x%02x\n",
                           col, row, expected, actual);
                errors++;
            }
        }
    }

    if (errors == 0) {
        printf("PASS: All pixels match (Y: %d pixels, UV: %d pixels)\n",
               CROP_W * CROP_H, CROP_W * uv_crop_h);
        free(src);
        free(dst);
        return 0;
    } else {
        printf("FAIL: %d pixel mismatches\n", errors);
        free(src);
        free(dst);
        return 1;
    }
}
