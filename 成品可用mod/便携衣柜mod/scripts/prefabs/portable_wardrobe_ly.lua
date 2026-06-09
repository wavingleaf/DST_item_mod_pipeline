-- ============================================================
-- portable_wardrobe_ly.lua — 便携衣柜（物品栏形态）
--
-- 双 Prefab 架构的"物品栏端"：
--   - 在物品栏中右键 → 打开容器 UI
--   - 拖到地面右键 → 部署为地面家具形态
--   - 部署时容器内容逐槽转移到新的地面家具实体
--
-- 参照原版：
--   portabletent.lua (itemfn) — deployable 组件的用法
--   backpack.lua             — container + inventoryitem 的组合模式
--   wardrobe.lua             — 衣柜动画资源
--   treasurechest.lua        — 宝箱音效复用
-- ============================================================

require "prefabutil"    -- 提供 MakePlacer 等工具函数

-- -----------------------------------------------------------------------
-- 资源声明
-- -----------------------------------------------------------------------
local assets =
{
    -- 衣柜动画（物品栏形态浮在地面上时显示为缩小的衣柜）
    Asset("ANIM", "anim/wardrobe.zip"),
    -- 占位 UI 动画：借用 chest 3×3（只用上 2 行 = 3列×2行）
    -- 后续替换为 ui_wardrobe_2x3.zip
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
    -- 占位图集：仅含 wardrobe.tex 一个元素，指向 inventoryimages.tex 大图
    -- 后续自定义图标后替换为自有图集
    Asset("ATLAS", "images/inventoryimages.xml"),
}

local prefabs =
{
    "portable_wardrobe_deployed_ly",    -- 部署后的地面家具实体
    "collapse_small",                   -- 锤子敲/烧毁时的崩塌特效
    "ash",                              -- 烧毁产物
}

-- -----------------------------------------------------------------------
-- 宝箱音效（复用原版宝箱的开关音效）
-- -----------------------------------------------------------------------
local SOUNDS =
{
    open  = "dontstarve/wilson/chest_open",
    close = "dontstarve/wilson/chest_close",
    built = "dontstarve/common/chest_craft",
}

-- -----------------------------------------------------------------------
-- 部署回调：物品栏形态 → 地面家具形态
-- 由 deployable 组件的 ondeploy 触发
-- -----------------------------------------------------------------------
local function OnDeploy(inst, pt, deployer)
    -- 生成地面家具实体
    local deployed = SpawnPrefab("portable_wardrobe_deployed_ly")
    if deployed == nil then
        return
    end

    -- 定位到部署点（地面版是结构物，没有 Physics 组件，用 Transform 即可）
    deployed.Transform:SetPosition(pt.x, 0, pt.z)

    -- 播放放置动画和音效
    deployed.AnimState:PlayAnimation("place")
    deployed.AnimState:PushAnimation("closed", false)
    deployed.SoundEmitter:PlaySound(SOUNDS.built)

    -- 逐槽转移容器内容
    -- 先收集旧容器的物品引用，清空旧 slots（避免 RemoveItem 触发 Drop），
    -- 再放入新容器同名槽位
    local saved = {}
    if inst.components.container then
        for i = 1, inst.components.container.numslots do
            saved[i] = inst.components.container.slots[i]
            inst.components.container.slots[i] = nil
        end
    end

    -- 关闭旧容器（清理 openlist 等状态）
    if inst.components.container then
        inst.components.container:Close()
    end

    -- 将保存的物品放入新容器的同名槽位
    if deployed.components.container then
        for i = 1, deployed.components.container.numslots do
            local item = saved[i]
            if item then
                -- GiveItem 负责设置 item.prevcontainer/item.prevslot、
                -- 触发 onputincontainerevnt 等事件
                deployed.components.container:GiveItem(item, i)
            end
        end
    end

    -- 销毁物品栏版实体
    inst:Remove()
end

-- -----------------------------------------------------------------------
-- 容器开关回调
-- -----------------------------------------------------------------------
local function onopen(inst)
    inst.SoundEmitter:PlaySound(SOUNDS.open)
end

local function onclose(inst)
    inst.SoundEmitter:PlaySound(SOUNDS.close)
end

-- -----------------------------------------------------------------------
-- 烧毁 / 点燃 / 熄火 回调
-- -----------------------------------------------------------------------
local function onburnt(inst)
    if inst.components.container then
        inst.components.container:DropEverything()       -- 全掉地上
        inst.components.container:Close()
    end
    SpawnPrefab("ash").Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst:Remove()
end

local function onignite(inst)
    if inst.components.container then
        inst.components.container.canbeopened = false    -- 燃烧中禁止操作
    end
end

local function onextinguish(inst)
    if inst.components.container then
        inst.components.container.canbeopened = true
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
    inst.entity:AddNetwork()

    -- 物理：物品可被捡起的大小
    MakeInventoryPhysics(inst)

    -- 动画：使用衣柜 bank/build，显示为闭合状态的缩小衣柜
    -- 衣柜原生动画集：closed / open / close / hit / place / active / cancel
    -- 物品形态仅需 closed（浮在地面时）和 place（部署时由新版播放）
    inst.AnimState:SetBank("wardrobe")
    inst.AnimState:SetBuild("wardrobe")
    inst.AnimState:PlayAnimation("closed")

    -- 不设 portablestorage 标签：带此标签的容器在 RUMMAGE 动作时
    -- 会路由到 start_pocket_rummage 状态（SGwilson.lua:1139-1142），播放
    -- build_pre→build_loop 持久弯腰翻找动画。去掉此标签后 stategraph
    -- 使用默认 doshortaction（标准弯腰取放动画），开关动画短且不锁定动作。
    --
    -- 同样不设 droponopen、不覆盖 OnUpdate——这些功能只在 portablestorage
    -- 标签下生效。去掉标签后全走普通箱子/容器逻辑：右击打开、左击拾取、
    -- UI 居中显示、走远了自动关。

    -- 浮动效果（丢在地上时的弹跳动画）
    -- "small" 尺寸，弹跳幅度 0.15
    MakeInventoryFloatable(inst, "small", 0.15,
        nil, nil, nil,
        { bank = "wardrobe", anim = "closed" })  -- swap_data：浮动时用衣柜 closed 态

    -- Pristine 分界线：以下代码仅服务端执行
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- ── 可检查 ──
    inst:AddComponent("inspectable")

    -- ── 物品栏 ──
    inst:AddComponent("inventoryitem")
    -- atlasname → resolvefilepath 查找（见 inventoryitem_replica.lua:159-160）
    -- imagename → 客户端 SetImage 追加 ".tex"（inventoryitem_replica.lua:132）
    -- 故 imagename 填 "wardrobe" 而非 "wardrobe.tex"
    inst.components.inventoryitem.atlasname = "images/inventoryimages.xml"
    inst.components.inventoryitem.imagename = "wardrobe"

    -- ── 容器 ──
    -- WidgetSetup 会从 containers.params["portable_wardrobe_ly"] 读取配置
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("portable_wardrobe_ly")
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose
    inst.components.container.skipclosesnd = true    -- 用自定义音效
    inst.components.container.skipopensnd = true
    -- 不设 droponopen、不设 portablestorage 标签、不覆盖 OnUpdate：
    -- RUMMAGE 动作使用 doshortaction 动画，容器 UI 居中打开，
    -- 在地上走远了自动关，在身上手动关。

    -- 覆盖 GetSpecificSlotForItem：原版只返回第一个 itemtestfn 通过的槽，
    -- 不检查是否被占（container.lua:298-303）。普通箱子无此问题是因为
    -- 它们不走此函数（usespecificslotsforitems=false），直接用"任意空槽"兜底。
    -- 我们的衣柜因为 usespecificslotsforitems=true 走了此路径，
    -- 且同一物品可匹配多列→需返回第一个"匹配且空闲"的槽。
    inst.components.container.GetSpecificSlotForItem = function(self, item)
        if self.usespecificslotsforitems and not self.readonlycontainer and self.itemtestfn ~= nil then
            for i = 1, self:GetNumSlots() do
                if self:itemtestfn(item, i) and self.slots[i] == nil then
                    return i
                end
            end
        end
    end

    -- ── 可部署 ──
    -- 拖到地面上右键时触发 OnDeploy
    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = OnDeploy
    -- DEPLOYMODE.DEFAULT 使用 Map:CanDeployAtPoint 做通用放置检测

    -- ── 可燃烧 ──
    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)
    inst.components.burnable:SetOnBurntFn(onburnt)
    inst.components.burnable:SetOnIgniteFn(onignite)
    inst.components.burnable:SetOnExtinguishFn(onextinguish)

    -- ── 可作祟 ──
    MakeHauntableLaunchAndDropFirstItem(inst)

    -- ── 掉落表 ──
    -- 物品被破坏/烧毁时需要这个组件才能正确掉落内容物
    inst:AddComponent("lootdropper")

    return inst
end

return Prefab("portable_wardrobe_ly", fn, assets, prefabs),
    -- 部署预览器：放置时显示衣柜的半透明预览
    MakePlacer("portable_wardrobe_ly_placer", "wardrobe", "wardrobe", "closed")
