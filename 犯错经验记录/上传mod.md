# 上传 Mod 到创意工坊

## 预览图（preview image）必须为 JPG 格式

### 现象

ModUploader 上传失败，仅提示"出错"无详细错误码。

### 根因

`preview.jpg` 必须是标准 baseline JPEG 格式。用 PNG 格式传上去会直接失败。

### 修复

将 PNG 用任意图片工具另存为 JPG，放到 mod 根目录，命名为 `preview.jpg`。
