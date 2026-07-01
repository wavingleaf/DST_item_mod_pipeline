-- ============================================================
-- modmain.lua — 便携衣柜
-- 服务端 + 客户端双端执行
-- ============================================================

-- 环境注入：让以下代码中直接写 TUNING / GLOBAL / STRINGS 等全局变量
-- 而不需要每次加 GLOBAL. 前缀。原理：当 Lua 在当前环境找不到变量时，
-- 会触发 __index 去 GLOBAL 中查找。
GLOBAL.setmetatable(env, { __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end })

-- 引入容器参数定义（widget布局、槽位坐标、itemtestfn等）
-- 通过往原版 containers.params 追加条目，让 WidgetSetup 自动找到我们的配置
modimport("scripts/portable_wardrobe_container_params_ly.lua")

-- 注册自定义 Prefab 文件（Klei 框架会在加载阶段检索这些 Prefab）
-- 注意：这里填的是不带 .lua 后缀的 Prefab 名，对应 scripts/prefabs/ 下的文件
PrefabFiles = {
    "portable_wardrobe_ly",
    "portable_wardrobe_deployed_ly",
}

-- ============================================================
-- 注册配方
-- ============================================================

-- 物品栏版：扣 5 血，无需科技，归类到"容器"分类
-- 注意：CHARACTER_INGREDIENT.HEALTH 必须为 5 的倍数，否则 recipe.lua 断言失败。
-- 这是 Klei 框架的硬约束（见 recipe.lua:16），取最小有效值 5。
-- placer 不填：填了会把配方变成"结构物摆放"模式，产物直接部署到地面
-- （不带 inventoryitem），捡不起来。物品栏版的部署由 deployable 组件在
-- 右键地面时触发，不走配方系统的 placer 机制。
local wardrobe_recipe = AddRecipe2(
    "portable_wardrobe_ly",
    { Ingredient(CHARACTER_INGREDIENT.HEALTH, 5) },
    TECH.NONE,
    {
        numtogive = 1,
        -- 配方栏图标：借用 wardrobe.tex（原版衣柜图标），图集文件已放置到 images/
        -- resolvefilepath 在 mod 加载时搜索 package.assetpath，mod 目录在搜索路径中
        -- Asset("ATLAS", ...) 在 prefab 中声明，运行时引擎能找到纹理
        atlas = "images/inventoryimages/portable_wardrobe_ly_inv.xml",
        image = "portable_wardrobe_ly_inv.tex",
    }
)

-- 将配方挂到新版制作栏的"容器"分类下
-- AddRecipeToFilter 由 Klei 框架在 modutil.lua 中注入到 mod 环境
AddRecipeToFilter("portable_wardrobe_ly", "CONTAINERS")

-- ============================================================
-- 本地化字符串
-- ============================================================

-- 物品栏版名称
GLOBAL.STRINGS.NAMES.PORTABLE_WARDROBE_LY = "便携衣柜"

-- 地面家具版名称（玩家通常不会直接看到这个 Prefab 名，但检查时可能显示）
GLOBAL.STRINGS.NAMES.PORTABLE_WARDROBE_DEPLOYED_LY = "便携衣柜(已部署)"

-- 检查描述
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.PORTABLE_WARDROBE_LY =
{
    GENERIC = "一个便携的装备收纳架，可以部署到地面上。",
}

GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.PORTABLE_WARDROBE_DEPLOYED_LY =
{
    GENERIC = "一个装备收纳架，右键可以收回。",
}
