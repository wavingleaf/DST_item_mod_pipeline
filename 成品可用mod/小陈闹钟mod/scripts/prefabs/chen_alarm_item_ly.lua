-- ============================================================
-- chen_alarm_item_ly.lua — 小陈闹钟（物品形态）
--
-- 双 Prefab 架构的"物品栏端"：
--   - 在物品栏中无任何效果，纯物品
--   - 拖到地面右键 → 部署为建筑物形态
--   - 不挂 container、不挂 workable、无碰撞
--
-- 全部使用自定义资源：动画（chen_alarm_ly.zip）+ 物品栏图标
--
-- 参照原版：
--   singingshell.lua           — 动画/音效/浮动物理参数
--   portable_wardrobe_ly.lua   — OnDeploy 模式 + deployable 组件用法
-- ============================================================

require "prefabutil"    -- 提供 MakePlacer 等工具函数

-- -----------------------------------------------------------------------
-- 资源声明（占位：全部借用原版 singingshell 资源）
-- -----------------------------------------------------------------------
local assets =
{
    -- 动画：小陈闹钟自定义动画（idle + music 两个动画状态）
    Asset("ANIM", "anim/chen_alarm_ly.zip"),
    -- 物品栏图标：自定义闹钟图标
    Asset("ATLAS", "images/inventoryimages/chen_alarm_item_ly_inv.xml"),
    Asset("IMAGE", "images/inventoryimages/chen_alarm_item_ly_inv.tex"),
}

local prefabs =
{
    "chen_alarm_deployed_ly",   -- 部署后生成的建筑物实体
}

-- -----------------------------------------------------------------------
-- 部署回调：物品形态 → 建筑物形态
-- 由 deployable 组件的 ondeploy 触发
-- -----------------------------------------------------------------------
local function OnDeploy(inst, pt, deployer)
    local deployed = SpawnPrefab("chen_alarm_deployed_ly")
    if deployed == nil then
        return
    end

    -- 定位到部署点
    -- 用 Transform:SetPosition 而非 Physics:Teleport，因为建筑物形态没有 Physics 组件
    deployed.Transform:SetPosition(pt.x, 0, pt.z)

    -- 初始显示 idle 动画（占位：贝壳钟的闲置态）
    deployed.AnimState:PlayAnimation("idle")

    -- 销毁物品栏版实体
    inst:Remove()
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

    -- 物理：可被捡起的物品大小
    MakeInventoryPhysics(inst)

    -- 动画：自定义闹钟 bank/build
    inst.AnimState:SetBank("chen_alarm_ly")
    inst.AnimState:SetBuild("chen_alarm_ly")
    inst.AnimState:PlayAnimation("idle")

    -- 拾取音效：石头声（和贝壳钟一致）
    inst.pickupsound = "rock"

    -- 浮动效果（丢在地上时的弹跳动画）
    -- 参数沿用中音贝壳钟（octave4）的配置：med 尺寸、0.58 缩放
    MakeInventoryFloatable(inst, "med", 0, 0.58)

    -- Pristine 分界线：以下代码仅服务端执行
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- ── 可检查 ──
    inst:AddComponent("inspectable")

    -- ── 物品栏 ──
    inst:AddComponent("inventoryitem")
    -- 自定义闹钟物品栏图标
    -- 参照便携衣柜的写法（portable_wardrobe_ly.lua:183-184），同时设置图集路径
    -- atlasname → resolvefilepath 查找（inventoryitem_replica.lua:159-160）
    -- imagename → 客户端 SetImage 追加 ".tex"（inventoryitem_replica.lua:132）
    -- 故 imagename 填 "chen_alarm_item_ly_inv" 而非 "chen_alarm_item_ly_inv.tex"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/chen_alarm_item_ly_inv.xml"
    inst.components.inventoryitem.imagename = "chen_alarm_item_ly_inv"

    -- ── 可部署 ──
    -- 拖到地面上右键时触发 OnDeploy
    -- DEPLOYMODE.DEFAULT 使用 Map:CanDeployAtPoint 做通用放置检测（不限地形）
    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = OnDeploy

    return inst
end

return Prefab("chen_alarm_item_ly", fn, assets, prefabs),
    -- 部署预览器：放置时显示闹钟的半透明预览
    MakePlacer("chen_alarm_item_ly_placer", "chen_alarm_ly", "chen_alarm_ly", "idle")
