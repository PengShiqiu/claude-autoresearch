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
        /* 预取后续行数据到 L1 缓存，隐藏内存延迟 */
        if (row + 2 < crop_h) {
            _mm_prefetch((char*)(src_y + 2 * src_stride), _MM_HINT_T0);
        }
        if (row + 4 < crop_h) {
            _mm_prefetch((char*)(src_y + 4 * src_stride), _MM_HINT_T0);
        }
        /* AVX2 主循环：4x展开，每次处理 128 字节 */
        int i = 0;
        for (; i + 128 <= vec_len; i += 128) {
            __m256i d0 = _mm256_loadu_si256((__m256i*)(src_y + i));
            __m256i d1 = _mm256_loadu_si256((__m256i*)(src_y + i + 32));
            __m256i d2 = _mm256_loadu_si256((__m256i*)(src_y + i + 64));
            __m256i d3 = _mm256_loadu_si256((__m256i*)(src_y + i + 96));
            _mm256_storeu_si256((__m256i*)(dst_y + i), d0);
            _mm256_storeu_si256((__m256i*)(dst_y + i + 32), d1);
            _mm256_storeu_si256((__m256i*)(dst_y + i + 64), d2);
            _mm256_storeu_si256((__m256i*)(dst_y + i + 96), d3);
        }
        /* 处理剩余 32 字节块 */
        for (; i < vec_len; i += 32) {
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
        /* 预取后续行数据到 L1 缓存，隐藏内存延迟 */
        if (row + 2 < uv_crop_h) {
            _mm_prefetch((char*)(src_uv + 2 * src_stride), _MM_HINT_T0);
        }
        if (row + 4 < uv_crop_h) {
            _mm_prefetch((char*)(src_uv + 4 * src_stride), _MM_HINT_T0);
        }
        /* AVX2 主循环：4x展开 */
        int i = 0;
        for (; i + 128 <= vec_len; i += 128) {
            __m256i d0 = _mm256_loadu_si256((__m256i*)(src_uv + i));
            __m256i d1 = _mm256_loadu_si256((__m256i*)(src_uv + i + 32));
            __m256i d2 = _mm256_loadu_si256((__m256i*)(src_uv + i + 64));
            __m256i d3 = _mm256_loadu_si256((__m256i*)(src_uv + i + 96));
            _mm256_storeu_si256((__m256i*)(dst_uv + i), d0);
            _mm256_storeu_si256((__m256i*)(dst_uv + i + 32), d1);
            _mm256_storeu_si256((__m256i*)(dst_uv + i + 64), d2);
            _mm256_storeu_si256((__m256i*)(dst_uv + i + 96), d3);
        }
        /* 处理剩余 32 字节块 */
        for (; i < vec_len; i += 32) {
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
