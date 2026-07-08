-- ============================================================
-- chen_alarm_deployed_ly.lua — 小陈闹钟（建筑物形态）
--
-- 双 Prefab 架构的"地面端"：
--   - 两个触发源：天色切换 + 玩家靠近
--   - 触发效果相同：播音频 + 照料作物 + 自身小动画
--   - 全局冷却，所有触发源共享
--   - 右键收回为物品形态（无锤子交互）
--   - 无碰撞、无容器
--
-- 全部使用自定义资源：动画（chen_alarm_ly.zip）+ 音效（chen_alarm.fev/.fsb）
--   音效为 3D 空间模式，音量 0.4，3~30 单位距离衰减
--
-- 参照原版：
--   singingshell.lua              — 动画/音效/照料作物逻辑（TendTo）
--   portable_wardrobe_deployed_ly.lua — portablestructure 收回模式
--   playerprox.lua                — 玩家靠近检测（AllPlayers 模式）
--   clock.lua / worldstate.lua    — WatchWorldState("phase") 天色监听
-- ============================================================

-- -----------------------------------------------------------------------
-- 资源声明（占位：全部借用原版 singingshell 资源）
-- -----------------------------------------------------------------------
local assets =
{
    -- 动画：小陈闹钟自定义动画（idle + music 两个动画状态）
    Asset("ANIM", "anim/chen_alarm_ly.zip"),
    -- 小地图图标：自定义闹钟图标（放在 minimap/ 目录，仅注册 ATLAS）
    -- 参照能力勋章 cookpot 的写法：minimap 图标不需 Asset("IMAGE", ...)
    Asset("ATLAS", "minimap/chen_alarm_minimap.xml"),
}

local prefabs =
{
    "chen_alarm_item_ly",   -- 收回时生成的物品形态
}

-- -----------------------------------------------------------------------
-- 可调参数（数值后续调参确定）
-- -----------------------------------------------------------------------

-- 照料作物的搜索标签（和原版贝壳钟一致：可照料农田作物）
local PLANT_TAGS = { "tendable_farmplant" }

local COOLDOWN   = 2       -- 全局冷却（秒）。最长音频约 1.36s，留 0.6s 余量

-- TEND_RANGE / PROX_NEAR / PROX_FAR 由 Mod 配置项驱动
-- 值在 modmain.lua 中从 GetModConfigData 读入 GLOBAL.TUNING.CHEN_ALARM_*

-- 自定义音频：3 段闹钟语音，加权随机选取
-- FMOD Designer 事件路径 = <.fdp项目名>/<组名>/<事件名>（Klei 官方通过 Steam Don't Starve Mod Tools 提供）
-- 权重分布：当当 50%（4/8），当破即破 25%（2/8），当断即断 25%（2/8）
-- 等比价签（1:1:1）即可满足需求，此处用 4:2:2 便于直观理解百分比
local ALARM_SOUNDS = {
    { event = "chen_alarm/sound/dangdang",       weight = 4 },  -- 0.70s
    { event = "chen_alarm/sound/dangpojipo",     weight = 2 },  -- 1.36s
    { event = "chen_alarm/sound/dangduanjiduan", weight = 2 },  -- 1.10s
}
-- 权重归一化：通过将权重之和转换为概率区间，再用 math.random() 在 [0,1) 上
-- 均匀取值，落在哪个区间就选哪个——避免多次 math.random() 调用或复杂的采样算法
local ALARM_TOTAL_WEIGHT = 8  -- 4 + 2 + 2
local function PickAlarmSound()
    -- math.random() 返回 [0,1) 区间均匀分布的浮点数
    local r = math.random()
    -- 0.00~0.49 → 当当 (50%)
    -- 0.50~0.74 → 当破即破 (25%)
    -- 0.75~0.99 → 当断即断 (25%)
    if r < 0.50 then
        return ALARM_SOUNDS[1].event
    elseif r < 0.75 then
        return ALARM_SOUNDS[2].event
    else
        return ALARM_SOUNDS[3].event
    end
end

-- -----------------------------------------------------------------------
-- 触发效果：播音频 + 做动画 + 照料作物
-- doer 参数：
--   玩家靠近触发时 → doer = 靠近的那个玩家
--   天色切换触发时 → doer = nil（TendTo(nil) 的安全性待测试验证）
-- -----------------------------------------------------------------------
local function DoTrigger(inst, doer)
    -- 全局冷却检查
    -- GetTime() 是引擎提供的全局函数，返回游戏内经过的秒数
    local current_time = GetTime()
    if inst._cooldown_end ~= nil and current_time < inst._cooldown_end then
        return  -- 冷却中，跳过
    end
    inst._cooldown_end = current_time + COOLDOWN

    -- ① 播放音频（受 mod 选项"音效"控制）
    if TUNING.CHEN_ALARM_SOUND_ENABLED then
        inst.SoundEmitter:PlaySound(PickAlarmSound())
    end

    -- ② 播放"抖一下"动画
    -- PlayAnimation 会中断当前动画并立即播放指定动画
    -- PushAnimation("idle", false) 在 music 播完后自动切回 idle
    -- 注意：如果两帧内连续触发（冷却 bug 导致），第二次 PlayAnimation 会
    -- 覆盖第一次 + 清掉第一次的 PushAnimation 待播队列，动画表现是重新抖一下
    inst.AnimState:PlayAnimation("music")
    inst.AnimState:PushAnimation("idle", false)

    -- ③ 照料范围内作物
    -- 原版贝壳钟相同逻辑：扫描范围内带 tendable_farmplant 标签的实体，
    -- 调用其 farmplanttendable 组件的 TendTo 方法
    local x, y, z = inst.Transform:GetWorldPosition()
    for _, v in ipairs(TheSim:FindEntities(x, y, z, TUNING.CHEN_ALARM_TEND_RANGE, PLANT_TAGS)) do
        -- 安全检查：确认目标实体确实有 farmplanttendable 组件
        -- 虽然 PLANT_TAGS 已经过滤了标签，但组件可能被其他 mod 移除
        if v.components.farmplanttendable ~= nil then
            v.components.farmplanttendable:TendTo(doer)
        end
    end
end

-- -----------------------------------------------------------------------
-- 触发源 ①：玩家靠近（playerprox 组件，AllPlayers 模式）
-- 每个玩家独立追踪，各自触发
-- -----------------------------------------------------------------------
local function OnPlayerNear(inst, player)
    DoTrigger(inst, player)
end

-- -----------------------------------------------------------------------
-- 触发源 ②：天色切换（WatchWorldState("phase")）
-- 白天→黄昏、黄昏→夜晚、夜晚→白天，任意 direction 变化均触发
-- -----------------------------------------------------------------------
local function OnPhaseChange(inst)
    DoTrigger(inst, nil)
end

-- -----------------------------------------------------------------------
-- 收回：建筑物形态 → 物品形态
-- 由 portablestructure 的 SetOnDismantleFn 触发（玩家右键）
-- doer 存在 → 放入 doer 背包；doer 不存在 → 掉在地上
-- -----------------------------------------------------------------------
local function ChangeToItem(inst, doer)
    local item = SpawnPrefab("chen_alarm_item_ly")
    if item == nil then
        inst:Remove()
        return
    end

    if doer ~= nil and doer.components.inventory ~= nil then
        -- 右键收回：收入背包
        doer.components.inventory:GiveItem(item)
    else
        -- doer 无效时的兜底：掉在地上
        item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end

    -- 移除地面版
    inst:Remove()
end

-- -----------------------------------------------------------------------
-- 存档 / 读档（保存冷却剩余时间，避免退出重进后冷却重置）
-- -----------------------------------------------------------------------
local function onsave(inst, data)
    if inst._cooldown_end ~= nil then
        local remaining = inst._cooldown_end - GetTime()
        if remaining > 0 then
            data.cooldown_remaining = remaining
        end
    end
end

local function onload(inst, data)
    if data ~= nil and data.cooldown_remaining ~= nil then
        inst._cooldown_end = GetTime() + data.cooldown_remaining
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

    -- 小地图图标：自定义闹钟图标（.tex 格式，引擎从 minimap/ 图集中查找）
    -- 图标已放大到 96×96（原 64×64 的 1.5 倍），便于地图上识别
    inst.MiniMapEntity:SetIcon("chen_alarm_minimap.tex")
    -- 优先级 6：高于绝大多数常见结构物，与藏宝图标记同级
    -- 原版优先级分布：-2(漩涡) -1(树) 0(默认) 1(火堆/猪王) 5(祭坛/科技建筑/虫洞) 7(眼骨/鱼缸) 10(玩家) 15(Boss)
    inst.MiniMapEntity:SetPriority(6)

    -- 标签：结构物（让游戏知道这是一个地面建筑，而非可拾取物品）
    inst:AddTag("structure")

    -- 动画：自定义闹钟 bank/build
    inst.AnimState:SetBank("chen_alarm_ly")
    inst.AnimState:SetBuild("chen_alarm_ly")
    inst.AnimState:PlayAnimation("idle")

    -- 注意：不调用 MakeInventoryPhysics(inst) → 没有 Physics 组件 → 无碰撞体积
    -- 也不调用任何物理相关函数，确保实体可穿透

    -- Pristine 分界线：以下代码仅服务端执行
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- ── 可检查 ──
    inst:AddComponent("inspectable")

    -- ── 触发源 ①：玩家靠近 ──
    -- playerprox 组件实现双阈值滞回检测，内置性能优化（默认 10 帧检测一次）
    -- AllPlayers 模式：每个玩家独立追踪，各自触发 OnPlayerNear
    inst:AddComponent("playerprox")
    -- 触发距离从 Mod 配置读取，PROX_FAR 已含缓冲间距
    inst.components.playerprox:SetDist(TUNING.CHEN_ALARM_PROX_NEAR, TUNING.CHEN_ALARM_PROX_FAR)
    -- TargetModes 通过组件实例访问（走 Lua 元表 __index 链回溯到 PlayerProx 类表）
    -- 各模式值：AnyPlayer / AllPlayers / SpecificPlayer / LockOnPlayer / LockAndKeepPlayer
    -- 参考：能力勋章 medal_origin_tree.lua:1030 相同写法
    inst.components.playerprox:SetTargetMode(inst.components.playerprox.TargetModes.AllPlayers)
    inst.components.playerprox:SetOnPlayerNear(OnPlayerNear)
    -- 不设 SetOnPlayerFar：玩家离开不需要做任何事

    -- ── 触发源 ②：天色切换 ──
    -- WatchWorldState 是实体方法，内部调用 TheWorld:WatchWorldState 并将
    -- inst 绑定到回调的第一个参数。当 phase 变化时 OnPhaseChange(inst) 被调用。
    -- 回调中不需要用 inst 参数也可以通过闭包访问外层的 inst，这里保留参数
    -- 用于清晰表达"这个回调接收被监听的实体"。
    inst:WatchWorldState("phase", OnPhaseChange)

    -- ── 便携结构（右键收回） ──
    -- portablestructure 组件注册 DISMANTLE 动作到实体上，右键触发
    -- 不挂 workable → 锤子无法交互（ACTIONS.HAMMER 不会被触发）
    inst:AddComponent("portablestructure")
    inst.components.portablestructure:SetOnDismantleFn(ChangeToItem)

    -- ── 存档 ──
    -- 保存冷却剩余时间，避免退出重进后冷却被重置导致意外触发
    inst.OnSave = onsave
    inst.OnLoad = onload

    return inst
end

return Prefab("chen_alarm_deployed_ly", fn, assets, prefabs)
