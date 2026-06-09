-- ============================================================
-- portable_wardrobe_container_params_ly.lua — 便携衣柜容器参数定义
-- 由 modmain.lua 通过 modimport("scripts/portable_wardrobe_container_params_ly.lua") 导入
--
-- 命名：带 mod 特征前缀 portable_wardrobe_，加 _ly 后缀。既避免与原版
-- containers.lua 冲突，也避免与其他 mod 的同名文件冲突。
--
-- 机制：往原版 containers.params 表追加条目。container 组件的
-- WidgetSetup 内部的 params[prefab] 查找会命中我们追加的键。
-- ============================================================

local containers = require("containers")

-- -----------------------------------------------------------------------
-- 槽位坐标计算
--
-- 容器布局：3列 × 2行 = 6格，借用 ui_chest_3x3 动画（只用上 2 行）
--
-- 坐标公式来自原版 treasurechest 的 slotpos 生成（containers.lua:1225-1228）：
--   x = 80*x - 80,  y = 80*y - 80
-- treasurechest 遍历 y=2,0,-1（3行），我们取 y=2,1（上 2 行）。
--
-- 迭代顺序（影响 itemtestfn 的匹配优先级）：
--   槽1→槽2→槽3→槽4→槽5→槽6
--   第1行(top, y=2): [保暖-头] [防水-头] [隔热-头]
--   第2行(bot, y=1): [保暖-身] [防水-身] [隔热-身]
--
-- y 值越大 = 越靠屏幕上方（ui_chest_3x3 的坐标体系），
-- 所以 head 行在 body 行上面，符合玩家直觉。
-- -----------------------------------------------------------------------
local slotpos = {}
for y = 2, 1, -1 do                             -- 2行，从上到下
    for x = 0, 2 do                             -- 3列，从左到右
        table.insert(slotpos, Vector3(
            80 * x - 80,                         -- 列（原文即此公式）
            80 * y - 80,                         -- 行（原文即此公式）
            0
        ))
    end
end

-- -----------------------------------------------------------------------
-- 槽位背景图标（slotbg）
-- 暂不设自定义背景。filter_*.tex 不在 images/hud.xml 中，
-- 引用不存在的纹理会导致崩溃。后续自有图集做好后在此填入。
-- nil 时框架使用动画自带的默认槽位背景。
-- -----------------------------------------------------------------------
local slotbg = nil

-- -----------------------------------------------------------------------
-- itemtestfn — 物品准入判断
--
-- 参数：
--   container : 容器组件实例
--   item      : 要放入的物品实体
--   slot      : 目标槽位编号 (1-6)
--
-- 返回值：true = 允许放入该槽
--
-- 槽位映射：
--   槽1: 头部 + 保暖  | 槽2: 头部 + 防水  | 槽3: 头部 + 隔热
--   槽4: 身体 + 保暖  | 槽5: 身体 + 防水  | 槽6: 身体 + 隔热
--
-- 判断逻辑：
--   1. 物品必须有 equippable 组件
--   2. equipslot 必须匹配所在行（"head" 或 "body"）
--   3. 所在列的天气保护组件必须存在且数值 > 0
--   4. 同一物品可同时匹配多列（框架按槽序迭代，首个匹配即入）
-- -----------------------------------------------------------------------
-- 判断单个槽位是否匹配物品的 equipslot + 天气属性
-- 抽取为局部函数，供 itemtestfn 在逐槽迭代时复用
local function CheckSlotMatch(item, slot)
    local eslot = item.components.equippable.equipslot

    -- 行判断：槽1-3是头部行，槽4-6是身体行
    if slot <= 3 then
        if eslot ~= "head" then
            return false
        end
    else
        if eslot ~= "body" then
            return false
        end
    end

    -- 列判断：(slot-1) % 3 得到 0(保暖),1(防水),2(隔热)
    local col = (slot - 1) % 3

    if col == 0 then
        -- 保暖列：insulator 存在 且 冬季类型 且 保暖值 > 0
        return item.components.insulator ~= nil
            and item.components.insulator:GetType() == SEASONS.WINTER
            and item.components.insulator:GetInsulation() > 0

    elseif col == 1 then
        -- 防水列：waterproofer 存在 且 防水效率 > 0
        return item.components.waterproofer ~= nil
            and item.components.waterproofer:GetEffectiveness() > 0

    else -- col == 2
        -- 隔热列：insulator 存在 且 夏季类型 且 隔热值 > 0
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

    -- slot 为 nil：框架在做"快速否决"检查（actions.lua:2491），
    -- 问"此物品能否放入任意槽位？"。此时需遍历所有槽，任一匹配即可。
    -- 之前直接 return false 导致物品被 NOTALLOWED 拒绝。
    if not slot then
        -- container 在服务端是 container component（有 numslots），
        -- 在客户端是 container_replica（用 _numslots）。
        local n = container._numslots or container.numslots
        for i = 1, n do
            if CheckSlotMatch(item, i) then
                return true
            end
        end
        return false
    end

    return CheckSlotMatch(item, slot)
end

-- =======================================================================
-- 往原版 containers.params 表追加便携衣柜的两个形态参数
-- =======================================================================

-- 物品栏形态：
--   不设 issidewidget（物品无装备位，无法锚定侧边栏）。
--   容器 UI 居中显示（仿箱子风格）。
--   在物品栏中右键打开的原理（见 actions.lua:1065-1093 RUMMAGE.fn）：
--     container.droponopen = true + tag "portablestorage" + owner 是玩家
--     → 跳过 DropItem，物品留在物品栏中，直接 Open。
--   部署由 deployable 组件独立处理（拖到地面右键触发）。
containers.params.portable_wardrobe_ly =
{
    widget =
    {
        slotpos = slotpos,
        slotbg = slotbg,
        -- 占位 UI 动画：借用 chest 3×3（只用上 2 行 = 3列×2行）
        -- 后续需要自定义 ui_wardrobe_2x3.zip
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),            -- 居中位置
        side_align_tip = 160,
    },
    type = "chest",
    usespecificslotsforitems = true,         -- 启用槽位准入检查
    itemtestfn = itemtestfn,
}

-- 地面家具形态：居中 UI（箱子风格），共享同样的槽位布局和 itemtestfn
containers.params.portable_wardrobe_deployed_ly =
{
    widget =
    {
        slotpos = slotpos,
        slotbg = slotbg,
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),            -- 居中位置（仿 chest）
        side_align_tip = 160,                -- 侧边对齐偏移（仿 chest）
    },
    -- 不设 issidewidget = nil → 居中 UI（chest 风格）
    type = "chest",
    usespecificslotsforitems = true,
    itemtestfn = itemtestfn,
}
