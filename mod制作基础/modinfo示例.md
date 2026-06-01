# modinfo.lua 示例

```lua
-- ============================================================
-- modinfo.lua — 所有字段按是否必须分组，注释说明用途
-- ============================================================

-- ──────────────────────────────
-- 必须字段（缺少任一，mod 无法启动）
-- ──────────────────────────────

name = "我的自定义Mod"
-- mod 在列表中的显示名称

description = "这是一个示例 Mod，展示了 modinfo.lua 的完整结构。"
-- mod 的详细描述，会在游戏内 mod 详情面板展示

author = "你的名字"
-- 作者署名

version = "1.0.0"
-- 版本号，字符串格式。建议遵循 semver（主版本.次版本.修订号）

api_version = 10
-- 必须为数字。决定 mod 与游戏内核 API 的兼容性。
-- 不匹配的 api_version 会导致 mod 无法加载。
-- 目前（2024年后）常用值为 10，具体查阅 Klei 官方文档。

dst_compatible = true
-- 是否兼容 Don't Starve Together（必填，通常为 true）

-- ──────────────────────────────
-- 可选但推荐的字段
-- ──────────────────────────────

forumthread = ""
-- 创意工坊、Klei 论坛或其他讨论帖的 URL，留空则无链接

icon_atlas = "modicon.xml"
-- mod 列表图标图集。未提供 modicon.png/xml 时设为 nil 或留空

icon = "modicon.tex"
-- mod 列表图标的纹理引用

-- ──────────────────────────────
-- 联网 & 客户端相关（可选）
-- ──────────────────────────────

all_clients_require_mod = true
-- true：所有加入服务器的客户端都必须订阅此 mod（默认推荐）
-- false：仅服务端需要，客户端不加也能加入
-- 纯客户端 mod（如 UI 美化）通常设为 false

client_only_mod = false
-- true：此 mod 仅影响客户端，服务端无需安装
-- 与 all_clients_require_mod 有交互关系，请理解后再设置

server_filter_tags = {}
-- 服务器列表筛选标签，留空为不添加标签
-- 例：{"角色", "物品"} 可以让玩家在服务器列表按标签搜索

-- ──────────────────────────────
-- Mod 配置选项（可选）
-- 让玩家在“Mod 配置”面板中自定义行为
-- ──────────────────────────────

configuration_options = {
    {
        name = "MY_NUMBER_OPTION",
        -- 选项的唯一标识，在 modmain.lua 中用
        -- GetModConfigData("MY_NUMBER_OPTION") 读取

        label = "数值选项",
        -- 玩家在配置面板看到的标签名

        hover = "调整某个数值的倍率",
        -- 鼠标悬停时的提示文本

        options = {
            {description = "低（0.5x）", data = 0.5},
            {description = "标准（1.0x）", data = 1.0},
            {description = "高（2.0x）", data = 2.0},
        },
        -- options: 下拉/单选。玩家看到的 description 是显示文本，
        -- 实际存入的值是 data。

        default = 1.0,
        -- 默认选中项（data 的值）
    },
    {
        name = "MY_BOOL_OPTION",
        label = "开关选项",
        hover = "开启或关闭某项功能",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false},
        },
        default = true,
    },
    {
        name = "MY_STRING_OPTION",
        label = "文本选项",
        options = {
            {description = "选项 A", data = "A"},
            {description = "选项 B", data = "B"},
        },
        default = "A",
    },
}

-- ──────────────────────────────
-- 优先加载标签（可选）
-- ──────────────────────────────

priority = 0
-- 决定多个 mod 之间的加载顺序，数字越大越靠后加载（越能覆盖前面的内容）。
-- 通常保持默认 0 即可，除非你明确需要覆盖其他 mod 的行为。

-- ──────────────────────────────
-- Don't Starve（单机版）兼容（可选）
-- ──────────────────────────────

dont_starve_compatible = false
-- 是否兼容单机版 DS。通常为 false，除非你明确做了兼容适配。

reign_of_giants_compatible = false
-- 是否兼容巨人国 DLC。同上了。

shipwrecked_compatible = false
-- 是否兼容海难 DLC。同上。

-- ──────────────────────────────
-- 调试 & 开发用（可选）
-- ──────────────────────────────

--[[
print("modinfo.lua loaded")
-- 可用于调试，但通常不需要。
-- 注意：modinfo 在极早期被加载，很多 API 此时不可用。
--]]
```
