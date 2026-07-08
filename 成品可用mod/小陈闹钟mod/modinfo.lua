-- ============================================================
-- modinfo.lua — 小陈闹钟
-- ============================================================

name = "小陈闹钟"
description = "陈千语款闹钟。放在地上定时照料周围作物，靠近时也会触发。"
author = "柳漾"
version = "0.1.0"

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = true

restart_required = false

forumthread = ""
priority = 0

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {"item", "farm"}

configuration_options =
{
    {
        name = "tend_range",
        label = "生效范围",
        hover = "闹钟照料周围农田作物的半径",
        options =
        {
            { description = "10（较小）", data = 10 },
            { description = "15", data = 15 },
            { description = "20（默认）", data = 20 },
            { description = "25", data = 25 },
            { description = "30（较大）", data = 30 },
        },
        default = 20,
    },
    {
        name = "prox_range",
        label = "触发范围",
        hover = "玩家靠近时触发闹钟的距离。值越大，缓冲间距也会适当增大",
        options =
        {
            { description = "6（较小）", data = 6 },
            { description = "9", data = 9 },
            { description = "12（默认）", data = 12 },
            { description = "15", data = 15 },
            { description = "18（较大）", data = 18 },
        },
        default = 12,
    },
    {
        name = "sound_enabled",
        label = "音效",
        hover = "触发时是否播放自定义音频",
        options =
        {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
}
