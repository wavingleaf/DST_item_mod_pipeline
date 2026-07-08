-- ============================================================
-- modmain.lua — 小陈闹钟
-- 服务端 + 客户端双端执行
-- ============================================================

-- 环境注入：让以下代码中直接写 TUNING / GLOBAL / STRINGS 等全局变量
-- 不需要每次加 GLOBAL. 前缀。原理：当 Lua 在当前环境找不到变量时，
-- 会触发 __index 去 GLOBAL 中查找。
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 读取 Mod 配置（必须提到顶层存为局部变量，GetModConfigData 不能在回调中调用）
-- 存入 TUNING 扩展表，供 prefab 文件直接访问（环境注入后 TUNING 无需 GLOBAL. 前缀）
local TEND_RANGE_CFG = GetModConfigData("tend_range") or 20
local PROX_RANGE_CFG = GetModConfigData("prox_range") or 12
local SOUND_ENABLED   = GetModConfigData("sound_enabled")
-- sound_enabled 是布尔值，GetModConfigData 可能返回 nil（未初始化时），此时默认开启
if SOUND_ENABLED == nil then SOUND_ENABLED = true end

-- 触发范围 → 缓冲半径：PROX_FAR = PROX_NEAR + 缓冲
-- 缓冲默认 2，当 NEAR > 14 时缓冲增至 3（避免大范围下频繁进出抖动）
local PROX_FAR_CFG = PROX_RANGE_CFG + (PROX_RANGE_CFG > 14 and 3 or 2)

GLOBAL.TUNING.CHEN_ALARM_TEND_RANGE   = TEND_RANGE_CFG
GLOBAL.TUNING.CHEN_ALARM_PROX_NEAR    = PROX_RANGE_CFG
GLOBAL.TUNING.CHEN_ALARM_PROX_FAR     = PROX_FAR_CFG
GLOBAL.TUNING.CHEN_ALARM_SOUND_ENABLED = SOUND_ENABLED

-- 注册自定义 Prefab 文件
PrefabFiles = {
    "chen_alarm_item_ly",
    "chen_alarm_deployed_ly",
}

-- 注册 FMOD Designer 自定义音效（SOUNDPACKAGE = .fev 事件定义，SOUND = .fsb 音频数据）
-- DST 只认 FMOD Designer 4.44.64 导出的 .fev/.fsb，FMOD Studio 的 .bank 格式不兼容
-- 事件路径格式：<.fdp项目名>/<组名>/<事件名>，组名固定为 "sound"
Assets = {
    Asset("SOUNDPACKAGE", "sound/chen_alarm.fev"),
    Asset("SOUND", "sound/chen_alarm.fsb"),
}

-- 注册小地图图集：minimap widget 只加载通过 AddMinimapAtlas 显式注册的图集，
-- 仅靠 prefab assets 表的 Asset("ATLAS", ...) 不够——后者只负责打包资源文件，
-- 前者才是告诉 minimap widget "加载这个图集，供 SetIcon 查找"的入口。
-- minimap.lua:44-48 遍历 ModManager:GetPostInitData("MinimapAtlases") 逐个 AddAtlas。
AddMinimapAtlas("minimap/chen_alarm_minimap.xml")

-- ============================================================
-- 本地化字符串
-- ============================================================

-- 物品栏版名称
GLOBAL.STRINGS.NAMES.CHEN_ALARM_ITEM_LY = "小陈闹钟"

-- 地面建筑版名称（玩家通常不会直接看到，但 debug/检查时可能显示）
GLOBAL.STRINGS.NAMES.CHEN_ALARM_DEPLOYED_LY = "小陈闹钟(已放置)"

-- 检查描述
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.CHEN_ALARM_ITEM_LY =
{
    GENERIC = "会时不时发出声音，植物也听得见",
}

GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.CHEN_ALARM_DEPLOYED_LY =
{
    GENERIC = "会时不时发出声音，植物也听得见",
}

-- ============================================================
-- 配方：1 中音贝壳钟 + 2 羊角，二本科技，工具栏（TOOLS）
-- ============================================================

-- TECH.SCIENCE_TWO = 炼金引擎（二本），{SCIENCE = 2}
-- singingshell_octave4 = 中音贝壳钟（原版 octave4 变体）
-- lightninggoathorn = 电羊角（闪电羊/伏特羊掉落物）
local alarm_recipe = AddRecipe2(
    "chen_alarm_item_ly",
    {
        Ingredient("singingshell_octave4", 1, nil, nil, "singingshell_octave4_1.tex"),
        Ingredient("lightninggoathorn", 2),
    },
    TECH.SCIENCE_TWO,
    {
        numtogive = 1,
        -- 自定义闹钟图标，需显式指定 atlas 路径，因为自定义图集不在游戏内置的
        -- inventoryimages1~4.xml 中，GetInventoryItemAtlas 自动扫描无法找到
        image = "chen_alarm_item_ly_inv.tex",
        atlas = "images/inventoryimages/chen_alarm_item_ly_inv.xml",
    }
)

-- AddRecipeToFilter 由 Klei 框架在 modutil.lua 中注入到 mod 环境，
-- 把配方挂到工具栏分类（工具/建筑/生存…中的"工具"）
AddRecipeToFilter("chen_alarm_item_ly", "TOOLS")

-- 配方描述（制作栏中鼠标悬停时显示）
GLOBAL.STRINGS.RECIPE_DESC.CHEN_ALARM_ITEM_LY = "定时？！当当！？（注：植物也会听）"
