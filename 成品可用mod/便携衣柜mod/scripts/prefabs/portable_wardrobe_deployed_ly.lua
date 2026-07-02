-- ============================================================
-- portable_wardrobe_deployed_ly.lua — 便携衣柜（地面家具形态）
--
-- 双 Prefab 架构的"地面端"：
--   - 左键 → 打开容器 UI
--   - 右键 → 收回为物品栏形态（仅在容器关闭时可执行）
--   - 锤子敲 → 收回为物品栏形态（不销毁内容物）
--
-- 模型使用缩小的原版衣柜动画（bank="wardrobe", build="wardrobe"）
-- 音效使用宝箱音效
--
-- 参照原版：
--   wardrobe.lua             — 衣柜动画资源（bank/build/animation states）
--   portabletent.lua (fn)    — portablestructure + 锤子敲回物品栏
--   treasurechest.lua        — 地面容器的动画/音效模式
--   componentactions.lua     — portablestructure 右键仅在容器关闭时可用
-- ============================================================

-- -----------------------------------------------------------------------
-- 资源声明
-- -----------------------------------------------------------------------
local assets =
{
    -- 自有动画：closed=关门闲置, open=开门, cancel=关门（无 hit / place 动画）
    Asset("ANIM", "anim/portable_wardrobe_ly.zip"),
    -- UI 背景动画（引用游戏内置，通常不会被其他 Mod 覆盖）
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
    -- 物品栏图标图集（地面版虽无 inventoryitem，但配方系统仍需要此图集）
    Asset("ATLAS", "images/inventoryimages/portable_wardrobe_ly_inv.xml"),
    Asset("IMAGE", "images/inventoryimages/portable_wardrobe_ly_inv.tex"),
}

local prefabs =
{
    "portable_wardrobe_ly",             -- 收回时生成物品栏版
    "collapse_small",                   -- 烧毁时的崩塌特效
}

-- -----------------------------------------------------------------------
-- 宝箱音效（按设计决策复用宝箱音效而非衣柜音效）
-- -----------------------------------------------------------------------
local SOUNDS =
{
    open  = "dontstarve/wilson/chest_open",
    close = "dontstarve/wilson/chest_close",
    built = "dontstarve/common/chest_craft",
}

-- -----------------------------------------------------------------------
-- 容器开关回调（动画 + 音效）
-- 衣柜有 open 和 cancel（关闭）动画状态
-- -----------------------------------------------------------------------
local function onopen(inst)
    if not inst:HasTag("burnt") then
        -- 衣柜原生 "open" 动画（开门）
        inst.AnimState:PlayAnimation("open")
        inst.SoundEmitter:PlaySound(SOUNDS.open)
    end
end

local function onclose(inst)
    if not inst:HasTag("burnt") then
        -- 衣柜原生 "cancel" 动画 = 关门（不同于宝箱的 "close"）
        -- 原版 wardrobe.lua 也使用 "cancel" 而非 "close" 来关门
        if inst.AnimState:IsCurrentAnimation("open") then
            inst.AnimState:PlayAnimation("cancel")
        end
        -- 如果不在 open 状态，说明容器被"放置"后的首次关闭，直接用空闲态
        inst.AnimState:PushAnimation("closed", false)
        inst.SoundEmitter:PlaySound(SOUNDS.close)
    end
end

-- -----------------------------------------------------------------------
-- 收回：地面家具形态 → 物品栏形态
-- 由 portablestructure.Dismantle（传 doer）或 workable.OnFinish（不传 doer）触发
-- doer 存在时：内容物转移到新物品，物品收入 doer 背包
-- doer 不存在时：物品掉在地上（锤子敲的场景）
-- -----------------------------------------------------------------------
local function ChangeToItem(inst, doer)
    -- 先关闭容器（确保 openlist 清理、玩家 UI 关闭）
    if inst.components.container then
        inst.components.container:Close()
    end

    -- 保存容器内容
    local saved = {}
    if inst.components.container then
        for i = 1, inst.components.container.numslots do
            saved[i] = inst.components.container.slots[i]
            inst.components.container.slots[i] = nil
        end
    end

    -- 生成物品栏版
    local item = SpawnPrefab("portable_wardrobe_ly")
    if item == nil then
        -- 生成失败则把物品掉在地上
        for i = 1, #saved do
            if saved[i] then
                saved[i].Transform:SetPosition(inst.Transform:GetWorldPosition())
                if saved[i].components.inventoryitem then
                    saved[i].components.inventoryitem:OnDropped(true)
                end
            end
        end
        inst:Remove()
        return
    end

    -- 将保存的物品放回同名槽位
    if item.components.container then
        for i = 1, item.components.container.numslots do
            local obj = saved[i]
            if obj then
                item.components.container:GiveItem(obj, i)
            end
        end
    end

    if doer ~= nil and doer.components.inventory ~= nil then
        -- 右键收回：收入背包
        doer.components.inventory:GiveItem(item)
    else
        -- 锤子敲或 doer 无效：掉在地上
        item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end

    -- 移除地面版
    inst:Remove()
end

-- -----------------------------------------------------------------------
-- 锤子敲的回调
-- -----------------------------------------------------------------------
local function OnHammered(inst, worker)
    -- 如果正在燃烧，先灭火
    if inst.components.burnable and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end

    if inst:HasTag("burnt") then
        -- 已烧毁状态：锤子敲 = 彻底销毁
        local fx = SpawnPrefab("collapse_small")
        inst.components.lootdropper:DropLoot()
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("wood")
        inst:Remove()
    else
        -- 正常状态：锤子敲 = 收回为物品栏形态
        ChangeToItem(inst)
    end
end

local function OnHit(inst, worker)
    if not inst:HasTag("burnt") then
        -- 无 hit 动画（自有动画只有 closed/open/cancel），锤击时保持 closed
        inst.AnimState:PlayAnimation("closed")
    end
end

-- -----------------------------------------------------------------------
-- 放置完成回调（无 place 动画，直接显示关门态 + 放置音效）
-- -----------------------------------------------------------------------
local function onbuilt(inst)
    inst.AnimState:PlayAnimation("closed")    -- 无 place 动画，直接用 closed
    inst.SoundEmitter:PlaySound(SOUNDS.built)
end

-- -----------------------------------------------------------------------
-- 烧毁
-- -----------------------------------------------------------------------
local function onburnt(inst)
    -- 先清空容器（物品掉落在地）
    if inst.components.container then
        inst.components.container:DropEverything()
        inst.components.container:Close()
    end
    -- 默认烧毁结构处理（变废墟）
    DefaultBurntStructureFn(inst)
    -- 移除物理碰撞
    RemovePhysicsColliders(inst)
    -- 烧毁后不能再拆卸
    if inst.components.portablestructure then
        inst:RemoveComponent("portablestructure")
    end
end

-- -----------------------------------------------------------------------
-- 存档 / 读档
-- -----------------------------------------------------------------------
local function onsave(inst, data)
    if inst.components.burnable and inst.components.burnable:IsBurning() or inst:HasTag("burnt") then
        data.burnt = true
    end
end

local function onload(inst, data)
    if data and data.burnt and inst.components.burnable then
        inst.components.burnable.onburnt(inst)
    end
end

-- -----------------------------------------------------------------------
-- Prefab 构造函数
-- -----------------------------------------------------------------------
local function fn()
    local inst = CreateEntity()

    -- 基础实体组件
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    -- 小地图图标（复用原版衣柜图标）
    inst.MiniMapEntity:SetIcon("wardrobe.png")

    -- 标签：结构物
    inst:AddTag("structure")

    -- 动画：自有 bank/build，含 closed/open/cancel 三个单帧
    inst.AnimState:SetBank("portable_wardrobe_ly")
    inst.AnimState:SetBuild("portable_wardrobe_ly")
    inst.AnimState:PlayAnimation("closed")

    MakeSnowCoveredPristine(inst)

    -- Pristine 分界线：以下仅服务端执行
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.sounds = SOUNDS

    -- ── 可检查 ──
    inst:AddComponent("inspectable")

    -- ── 容器 ──
    -- WidgetSetup 从 containers.params["portable_wardrobe_deployed_ly"] 读取配置
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("portable_wardrobe_deployed_ly")
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose
    inst.components.container.skipclosesnd = true       -- 用我们的自定义音效
    inst.components.container.skipopensnd = true

    -- 覆盖：返回第一个匹配且空闲的槽（同物品栏版，原理见该文件注释）
    inst.components.container.GetSpecificSlotForItem = function(self, item)
        if self.usespecificslotsforitems and not self.readonlycontainer and self.itemtestfn ~= nil then
            for i = 1, self:GetNumSlots() do
                if self:itemtestfn(item, i) and self.slots[i] == nil then
                    return i
                end
            end
        end
    end

    -- IsEmpty 始终返回 true：绕过 DISMANTLE 动作的 NOTEMPTY 检查
    --（actions.lua:4513）。我们的 ChangeToItem 自身会处理内容物转移，
    -- 不需要框架帮我们拦截。
    inst.components.container.IsEmpty = function() return true end

    -- ── 便携结构（右键收回） ──
    -- SetOnDismantleFn 设置右键"拆卸"的实际行为
    -- 框架 componentactions.lua:680 已处理：容器打开时右键不显示"拆卸"
    inst:AddComponent("portablestructure")
    inst.components.portablestructure:SetOnDismantleFn(ChangeToItem)

    -- ── 可工作（锤子敲） ──
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)               -- 敲 4 下收回
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    -- ── 可燃烧 ──
    MakeSmallBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)
    inst.components.burnable:SetOnBurntFn(onburnt)

    -- ── 可作祟 ──
    MakeHauntableWork(inst)
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    -- ── 放置事件 ──
    inst:ListenForEvent("onbuilt", onbuilt)

    -- ── 积雪效果（原版建筑惯例） ──
    MakeSnowCovered(inst)
    SetLunarHailBuildupAmountSmall(inst)

    -- ── 存档 ──
    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("portable_wardrobe_deployed_ly", fn, assets, prefabs)
