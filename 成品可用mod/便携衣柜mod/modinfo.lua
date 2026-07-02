-- ============================================================
-- modinfo.lua — 便携衣柜
-- ============================================================

name = "便携衣柜"
description = "随身的装备收纳架。3×3格子，按头/身和保暖/防水/隔热分类，可部署到地面。永鲜保鲜，方便花衬衫、冰帽等新鲜度装备。"
author = ""
version = "0.2.0"

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true
client_only_mod = false

forumthread = ""
priority = 0

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {"物品", "容器"}

configuration_options =
{
    {
        name = "ETERNAL_FRESH",
        label = "永鲜",
        hover = "永鲜保鲜，方便花衬衫、冰帽等新鲜度装备。",
        options =
        {
            { description = "开启（默认）", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
}
