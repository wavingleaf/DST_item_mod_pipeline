-- ============================================================
-- modinfo.lua — 便携衣柜
-- ============================================================

name = "便携衣柜"
description = "随身的装备收纳架。2×3格子，按头/身和保暖/防水/隔热分类，可部署到地面。内部永鲜。"
author = "柳漾, 只会喵喵叫的猫猫虫"
version = "1.0.0"

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

server_filter_tags = {"item", "container"}

configuration_options =
{
    {
        name = "ETERNAL_FRESH",
        label = "永鲜",
        hover = "衣柜中的物品永鲜保鲜。",
        options =
        {
            { description = "开启（默认）", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
}
