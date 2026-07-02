-- ============================================================
-- portable_wardrobe_container_params_ly.lua — 便携衣柜容器参数定义
-- 由 modmain.lua 通过 modimport("scripts/portable_wardrobe_container_params_ly.lua") 导入
-- ============================================================

local containers = require("containers")

-- -----------------------------------------------------------------------
-- 槽位坐标计算
--
-- 容器布局：3列 × 3行 = 9格（首行为装饰行，不放物品）
--
-- 坐标公式来自原版 treasurechest 的 slotpos 生成（containers.lua:1225-1228）：
--   x = 80*x - 80,  y = 80*y - 80
--
-- 迭代顺序：
--   槽1→槽2→槽3→槽4→槽5→槽6→槽7→槽8→槽9
--   第1行(top,   y=2): [❄保暖] [💧防水] [☀隔热]  ← 装饰行，不可放物
--   第2行(mid,   y=1): [🎩保暖] [🎩防水] [🎩隔热]  ← 头部装备
--   第3行(bot,   y=0): [👔保暖] [👔防水] [👔隔热]  ← 身体装备
-- -----------------------------------------------------------------------
local slotpos = {}
for y = 2, 0, -1 do                             -- 3行，从上到下
    for x = 0, 2 do                             -- 3列，从左到右
        table.insert(slotpos, Vector3(
            80 * x - 80,                         -- 列
            80 * y - 80,                         -- 行
            0
        ))
    end
end

-- -----------------------------------------------------------------------
-- 槽位背景图标（slotbg）
--
-- 装饰行用原版科技栏分类图标（filter_winter/filter_rain/filter_summer），
-- 物品行用原版装备栏图标（equip_slot_head_hud / equip_slot_body_hud）。
-- 引用原版游戏内置图集。
-- 若其他 Mod 修改了这些图集，槽位背景可能受影响，但概率极低。
-- -----------------------------------------------------------------------
local slotbg = {
    -- 第1行（装饰）：保暖 / 防水 / 隔热 示意
    { image = "filter_winter.tex", atlas = "images/crafting_menu_icons.xml" },
    { image = "filter_rain.tex",   atlas = "images/crafting_menu_icons.xml" },
    { image = "filter_summer.tex", atlas = "images/crafting_menu_icons.xml" },

    -- 第2行（头部）：帽子图标 ×3
    { image = "equip_slot_head.tex", atlas = "images/hud.xml" },
    { image = "equip_slot_head.tex", atlas = "images/hud.xml" },
    { image = "equip_slot_head.tex", atlas = "images/hud.xml" },

    -- 第3行（身体）：衣服图标 ×3
    { image = "equip_slot_body.tex", atlas = "images/hud.xml" },
    { image = "equip_slot_body.tex", atlas = "images/hud.xml" },
    { image = "equip_slot_body.tex", atlas = "images/hud.xml" },
}

-- -----------------------------------------------------------------------
-- itemtestfn — 物品准入判断
--
-- 槽位映射（9槽总记数）：
--   槽1-3: 装饰行 — itemtestfn 永远返回 false，框架阻止放入
--   槽4-6: 头部行 — 仅接受 equipslot=="head" + 对应天气属性
--   槽7-9: 身体行 — 仅接受 equipslot=="body" + 对应天气属性
--
-- 列判断：用 (slot-1) % 3 → 0=保暖, 1=防水, 2=隔热（三行共用同一列规则）
-- -----------------------------------------------------------------------

-- 判断物品是否匹配某槽的装备部位 + 天气属性
local function CheckSlotMatch(item, slot)
    local eslot = item.components.equippable.equipslot

    -- 行判断：槽4-6是头部行，槽7-9是身体行
    -- 槽1-3不进入此函数（itemtestfn 直接拒绝，见下方）
    if slot <= 6 then
        if eslot ~= "head" then return false end
    else
        if eslot ~= "body" then return false end
    end

    -- 列判断：(slot-1) % 3 → 0(保暖), 1(防水), 2(隔热)
    local col = (slot - 1) % 3

    if col == 0 then
        return item.components.insulator ~= nil
           and item.components.insulator:GetType() == SEASONS.WINTER
           and item.components.insulator:GetInsulation() > 0
    elseif col == 1 then
        return item.components.waterproofer ~= nil
           and item.components.waterproofer:GetEffectiveness() > 0
    else -- col == 2
        return item.components.insulator ~= nil
           and item.components.insulator:GetType() == SEASONS.SUMMER
           and item.components.insulator:GetInsulation() > 0
    end
end

local function itemtestfn(container, item, slot)
    -- 没有 equippable 组件 = 不是装备，直接拒绝
    if not item.components.equippable then
        return false
    end

    -- slot 为 nil：框架的"快速否决"检查（actions.lua:2491），
    -- 问"此物品能否放入任意槽位？"。需遍历所有可放物品的槽（槽4-9）。
    if not slot then
        local n = container._numslots or container.numslots
        for i = 1, n do
            -- 跳过装饰行（槽1-3）
            if i > 3 and CheckSlotMatch(item, i) then
                return true
            end
        end
        return false
    end

    -- 装饰行（槽1-3）：拒绝放入任何物品
    if slot <= 3 then
        return false
    end

    return CheckSlotMatch(item, slot)
end

-- =======================================================================
-- 往原版 containers.params 表追加便携衣柜的两个形态参数
-- =======================================================================

containers.params.portable_wardrobe_ly =
{
    widget =
    {
        slotpos = slotpos,
        slotbg = slotbg,
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),            -- 居中位置
        side_align_tip = 160,

        -- 逐槽缩放：装饰行（前3槽）缩放到 25%，物品行保持原大
        -- containerwidget.lua 逐槽调用 slotscalefn(container, doer)，
        -- 框架不传槽号 i，故用 container 上的计数器迂回区分。
        slotscalefn = function(container, doer)
            container.__slot_scale_i = (container.__slot_scale_i or -1) + 1
            if container.__slot_scale_i >= 9 then
                container.__slot_scale_i = 0
            end
            if container.__slot_scale_i < 3 then
                return 0.25             -- 装饰行缩放 25%
            else
                return 1.0              -- 物品行保持原大
            end
        end,
    },
    type = "chest",
    usespecificslotsforitems = true,
    itemtestfn = itemtestfn,
}

containers.params.portable_wardrobe_deployed_ly =
{
    widget =
    {
        slotpos = slotpos,
        slotbg = slotbg,
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,

        slotscalefn = function(container, doer)
            container.__slot_scale_i = (container.__slot_scale_i or -1) + 1
            if container.__slot_scale_i >= 9 then
                container.__slot_scale_i = 0
            end
            if container.__slot_scale_i < 3 then
                return 0.25
            else
                return 1.0
            end
        end,
    },
    type = "chest",
    usespecificslotsforitems = true,
    itemtestfn = itemtestfn,
}
