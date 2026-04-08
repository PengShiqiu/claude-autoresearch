#ifndef NV12_CROP_H
#define NV12_CROP_H

#include <stdint.h>
#include <stddef.h>

/**
 * NV12 格式说明:
 * - Y 平面: width * height 字节, 行 stride = src_stride
 * - UV 平面: 紧跟 Y 平面之后, width * height/2 字节, 行 stride = src_stride
 * - UV 交错存储: U0V0 U1V1 U2V2 ...
 *
 * crop 参数:
 * - (crop_x, crop_y) 裁剪起始位置 (crop_x 必须为偶数)
 * - (crop_w, crop_h) 裁剪区域大小 (crop_w, crop_h 必须为偶数)
 */

typedef struct {
    int width;      // 源图宽度
    int height;     // 源图高度
    int src_stride; // 源图行 stride (字节)
} nv12_image_t;

/**
 * NV12 crop 主函数
 *
 * @param src        源 NV12 数据指针 (Y 平面起始)
 * @param src_info   源图信息
 * @param dst        目标 NV12 数据指针 (预分配, Y 平面起始)
 * @param dst_stride 目标行 stride
 * @param crop_x     裁剪起始 X (必须偶数)
 * @param crop_y     裁剪起始 Y (必须偶数)
 * @param crop_w     裁剪宽度 (必须偶数)
 * @param crop_h     裁剪高度 (必须偶数)
 */
void nv12_crop(const uint8_t *src, const nv12_image_t *src_info,
               uint8_t *dst, int dst_stride,
               int crop_x, int crop_y, int crop_w, int crop_h);

#endif /* NV12_CROP_H */
