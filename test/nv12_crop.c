#include <string.h>
#include <immintrin.h>
#include "nv12_crop.h"

/**
 * NV12 crop AVX2 优化实现
 *
 * 优化点：
 * - 使用 AVX2 intrinsic 替代 memcpy，一次处理 32 字节
 * - 减少函数调用开销（每次行复制不再调用 memcpy）
 * - 主循环处理 32 字节对齐部分，尾部处理剩余字节
 */
void nv12_crop(const uint8_t *src, const nv12_image_t *src_info,
               uint8_t *dst, int dst_stride,
               int crop_x, int crop_y, int crop_w, int crop_h)
{
    const int src_stride = src_info->src_stride;
    const int vec_len = crop_w & ~31;  /* 32字节对齐部分长度 */

    /* Y 平面复制 */
    const uint8_t *src_y = src + (size_t)crop_y * src_stride + crop_x;
    uint8_t *dst_y = dst;

    for (int row = 0; row < crop_h; row++) {
        /* AVX2 主循环：每次处理 32 字节 */
        for (int i = 0; i < vec_len; i += 32) {
            __m256i data = _mm256_loadu_si256((__m256i*)(src_y + i));
            _mm256_storeu_si256((__m256i*)(dst_y + i), data);
        }
        /* 处理尾部剩余字节 */
        if (crop_w & 31) {
            memcpy(dst_y + vec_len, src_y + vec_len, crop_w & 31);
        }
        src_y += src_stride;
        dst_y += dst_stride;
    }

    /* UV 平面复制 */
    const int uv_crop_y = crop_y / 2;
    const int uv_crop_h = crop_h / 2;
    const uint8_t *src_uv = src + (size_t)src_info->height * src_stride
                              + (size_t)uv_crop_y * src_stride + crop_x;
    uint8_t *dst_uv = dst + (size_t)crop_h * dst_stride;

    for (int row = 0; row < uv_crop_h; row++) {
        /* AVX2 主循环 */
        for (int i = 0; i < vec_len; i += 32) {
            __m256i data = _mm256_loadu_si256((__m256i*)(src_uv + i));
            _mm256_storeu_si256((__m256i*)(dst_uv + i), data);
        }
        /* 处理尾部 */
        if (crop_w & 31) {
            memcpy(dst_uv + vec_len, src_uv + vec_len, crop_w & 31);
        }
        src_uv += src_stride;
        dst_uv += dst_stride;
    }
}
