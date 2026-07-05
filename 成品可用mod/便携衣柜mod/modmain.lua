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
-- 读取 Mod 配置
-- ============================================================

-- GetModConfigData 不能在回调内调用，必须提到顶层存为局部变量再用。
-- 这是 Klei 框架的硬约束：mod 加载阶段结束后配置数据可能不可用。
local ETERNAL_FRESH = GetModConfigData("ETERNAL_FRESH")

-- ============================================================
-- 注册配方
-- ============================================================

-- 原料：3 木板 + 2 噩梦燃料 + 1 橙宝石，需要暗影操纵仪（魔法 2 本）
-- Klei 的 TECH 命名跳过了 MAGIC_ONE，MAGIC_THREE = { MAGIC = 3 } = 暗影操纵仪
-- placer 不填：填了会把配方变成"结构物摆放"模式，产物直接部署到地面
-- （不带 inventoryitem），捡不起来。物品栏版的部署由 deployable 组件在
-- 右键地面时触发，不走配方系统的 placer 机制。
local wardrobe_recipe = AddRecipe2(
    "portable_wardrobe_ly",
    {
        Ingredient("boards", 3),
        Ingredient("nightmarefuel", 2),
        Ingredient("orangegem", 1),
    },
    TECH.MAGIC_THREE,
    {
        numtogive = 1,
        atlas = "images/inventoryimages/portable_wardrobe_ly_inv.xml",
        image = "portable_wardrobe_ly_inv.tex",
    }
)

-- 将配方挂到"容器"和"魔法"两个分类下
-- AddRecipeToFilter 由 Klei 框架在 modutil.lua 中注入到 mod 环境
AddRecipeToFilter("portable_wardrobe_ly", "CONTAINERS")
AddRecipeToFilter("portable_wardrobe_ly", "MAGIC")

-- ============================================================
-- 永鲜逻辑
-- ============================================================

-- 原理：container 组件的 GiveItem 和 RemoveItem 分别负责放入和取出。
-- 我们在这两个方法的调用前后调用 perishable 的 StopPerishing / StartPerishing。
-- 形态转换（OnDeploy / ChangeToItem）直接操作 slots 数组绕过 RemoveItem，
-- 因此不会触发 StartPerishing，内容物在两个形态间转移时保持永鲜状态。
-- 物品被烧毁/掉落时走 DropEverything → RemoveItemBySlot → RemoveItem，
-- 会正常触发 StartPerishing 恢复腐烂。

local function AddEternalFresh(inst)
    if not ETERNAL_FRESH then return end
    if not inst.components.container then return end

    local container = inst.components.container

    -- 放入物品时停止腐烂
    local old_GiveItem = container.GiveItem
    container.GiveItem = function(self, item, slot, ...)
        if item.components.perishable then
            item.components.perishable:StopPerishing()
        end
        return old_GiveItem(self, item, slot, ...)
    end

    -- 取出物品时恢复腐烂
    local old_RemoveItem = container.RemoveItem
    container.RemoveItem = function(self, item, ...)
        if item.components.perishable then
            item.components.perishable:StartPerishing()
        end
        return old_RemoveItem(self, item, ...)
    end
end

-- 给两个 Prefab 形态都加上永鲜逻辑
AddPrefabPostInit("portable_wardrobe_ly", AddEternalFresh)
AddPrefabPostInit("portable_wardrobe_deployed_ly", AddEternalFresh)

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
    GENERIC = "按头/身和保暖/防水/隔热分类收纳装备，可部署到地面。内部永鲜。",
}

GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.PORTABLE_WARDROBE_DEPLOYED_LY =
{
    GENERIC = "一个装备收纳架，右键可以收回。",
}

-- 配方描述（制作栏中鼠标悬停时显示）
GLOBAL.STRINGS.RECIPE_DESC.PORTABLE_WARDROBE_LY = "随身应季衣柜，新鲜度装备在其中永鲜。"
