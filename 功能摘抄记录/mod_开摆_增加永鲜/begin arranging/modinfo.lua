local isCh = locale == "zh" or locale == "zhr"--是否为中文
name = isCh and "开摆！" or "Place Everything"
description = isCh and [[当前版本1.0.0.6
新增了一顶帽子：不安全帽(二本科技解锁)
玩家佩戴不安全帽时，可以把所有可放到物品栏的道具安置到地上作为装饰，防止不小心拿起来~
也只能在佩戴不安全帽时，把放置在地上的物品取回~]] or [[Current version 1.0.0.4
Added recipe for unsafe hat
When players wear unsafe hat, they can place all items that can be placed in the item slot on the ground as decorations to prevent them from being accidentally picked up~]]
author = ""

version = "1.0.0.6"--整体.大章节.小章节.优化、修Bug

api_version = 10
priority = -1--优先级调高

dont_starve_compatible = true
reign_of_giants_compatible = true
dst_compatible = true
restart_required = false
all_clients_require_mod = true
icon = "modicon.tex"
icon_atlas = "modicon.xml"

configuration_options =
{
	{
		name = "language_switch",
		label = isCh and "选择语言" or "Language",
		hover = isCh and "选择你的常用语言" or "Choose your common language",
		options =
		{
			{description = "中文", data = "ch", hover = "中文"},
			{description = "English", data = "eng", hover = "English"},
		},
		default = isCh and "ch" or "eng",
	},
}