GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

PrefabFiles = {
	"decorationitem_placer",
	"unsafehat",
}

--语言
if GetModConfigData("language_switch") =="ch" then 
	require "lang/decorationitem_strings_ch"
else
	require "lang/decorationitem_strings_eng"
end

--变成不可拾取的装饰品
local function changeDecorationItem(inst)
	if inst.components.inventoryitem then
		if inst.components.inventoryitem.ondropfn ~= nil then
			inst.components.inventoryitem.ondropfn(inst)
		end
		inst:PushEvent("ondropped")--还是推事件吧，不然哪怕重载游戏也照样会切状态
		inst.components.inventoryitem.canbepickedup=false
	end
	if inst.components.stackable and not inst:HasTag("net_workable") then
		inst:RemoveComponent("stackable")
		inst.once_stackable = true
	end
	inst:AddTag("outofreach")--防偷
	inst:AddTag("decorationitem")--已放置的装饰品标签

	-- 通过腐烂速率×0实现放置保鲜（SetPerishRateMultiplier方案）
	-- 计时器仍在运行，但速率×0使得perishremainingtime不会减少
	-- _decoration_old_perish_mult 记录原始倍率，取回时恢复
	-- 用 nil 检查防止读档后 changeDecorationItem 重复调用时覆盖持久化的原始值
	if inst.components.perishable then
		if inst._decoration_old_perish_mult == nil then
			inst._decoration_old_perish_mult = inst.components.perishable:GetLocalMultiplier()
		end
		inst.components.perishable:SetLocalMultiplier(0)
	end
end
--放置
local function ondeploy(inst, pt, deployer)
	inst.Transform:SetPosition(pt.x,pt.y,pt.z)
	changeDecorationItem(inst)
end

--给全部的可库存道具加为饰品
AddPrefabPostInitAny(function(inst)
	if inst:HasTag("_inventoryitem") then--这里有个坑，如果已经有_inventoryitem Tag了，说明这个预置物已经在主机上添加过inventoryitem组件了，这里相当于已经把客机的预置物过滤掉了
		inst:AddTag("isdecorationitem")--是可装饰道具(由于上述原因，只能用tag，不能用客机变量了)
		if TheWorld.ismastersim then
			local oldSaveFn=inst.OnSave
			local oldLoadFn=inst.OnLoad
			inst.DecorationDeploy=ondeploy--放置，不应该用deployable组件，免得把原来的功能冲了
			inst.OnSave = function(inst,data)
				if oldSaveFn~=nil then
					oldSaveFn(inst,data)
				end
				if inst:HasTag("decorationitem") then
					data.decorationitem=true
					-- 持久化原始腐烂倍率，防止读档后丢失
					if inst._decoration_old_perish_mult ~= nil then
						data._decoration_old_perish_mult = inst._decoration_old_perish_mult
					end
				end
			end
			inst.OnLoad = function(inst,data)
				if oldLoadFn~=nil then
					oldLoadFn(inst,data)
				end
				if data~=nil and data.decorationitem then
					-- 先恢复持久化的原始腐烂倍率，再调 changeDecorationItem
					-- changeDecorationItem 检测到 _decoration_old_perish_mult 已有值就不覆盖
					if data._decoration_old_perish_mult ~= nil then
						inst._decoration_old_perish_mult = data._decoration_old_perish_mult
					end
					changeDecorationItem(inst)
				end
			end
		end
	end
end)

--坐标点是否可放置
function DecorationCanDeployAtPoint(pt, inst)
    local x,y,z = pt:Get()
	return TheWorld.Map:IsPassableAtPointWithPlatformRadiusBias(x,y,z, false, false, TUNING.BOAT.NO_BUILD_BORDER_RADIUS, true)
        and TheWorld.Map:IsDeployPointClear(pt, inst, 0)
end
GLOBAL.DecorationCanDeployAtPoint = DecorationCanDeployAtPoint
--hook预置物的是否可种植校验方法，方便placer的正常显示
AddClassPostConstruct("components/inventoryitem_replica", function(self)
	local oldGetDeployPlacerName = self.GetDeployPlacerName
	self.GetDeployPlacerName = function(self)
		if self.inst and self.inst:HasTag("isdecorationitem") then
			local owner = self.inst.components.inventoryitem ~= nil and self.inst.components.inventoryitem:GetGrandOwner() or ThePlayer
			if owner~=nil and owner:HasTag("item_decorator") or not (self.classified and self.classified.deploymode:value() ~= DEPLOYMODE.NONE) then
				return "decorationitem_placer"--装饰品统一用这个placer
			end
		end
		return oldGetDeployPlacerName and oldGetDeployPlacerName(self)
	end
	local oldIsDeployable=self.IsDeployable
    self.IsDeployable = function(self,deployer)
        if deployer and deployer:HasTag("item_decorator") and self.inst:HasTag("isdecorationitem") then
			return true
		end
		return oldIsDeployable and oldIsDeployable(self,deployer)
    end
	local oldCanDeploy=self.CanDeploy
    self.CanDeploy = function(self, pt, mouseover, deployer, rot)
        if deployer and deployer:HasTag("item_decorator") and self.inst:HasTag("isdecorationitem") then
			return DecorationCanDeployAtPoint(pt, self.inst)
		elseif oldCanDeploy then
			return oldCanDeploy(self, pt, mouseover, deployer, rot)
		end
    end
end)

--对于特定placer就没必要加皮肤了，防止报错
local oldSpawnPrefab = GLOBAL.SpawnPrefab
GLOBAL.SpawnPrefab = function(name, skin, skin_id, creator,...)
	if name=="decorationitem_placer" then 
		local newitem = oldSpawnPrefab and oldSpawnPrefab(name)
		newitem.skinname = skin--但是还是要记录下皮肤信息，因为playercontroller会做校验，不通过的话会一直重复生成placer造成卡顿
		return newitem
	end
	return oldSpawnPrefab and oldSpawnPrefab(name, skin, skin_id, creator,...)
end
--防止放置可装备物品的时候自动装备
AddComponentPostInit("playercontroller", function(self)
	local oldDoActionAutoEquip=self.DoActionAutoEquip
	self.DoActionAutoEquip = function(self,buffaction)
		if buffaction and buffaction.action ~= ACTIONS.DEPLOYDECORATION then
			if oldDoActionAutoEquip then
				oldDoActionAutoEquip(self,buffaction)
			end
		end
	end
	--修正物品摆放位置
	local oldDoAction = self.DoAction
	self.DoAction = function(self,buffaction,...)
		if buffaction ~= nil and buffaction.action == ACTIONS.DEPLOYDECORATION then
			if self.inst and self.inst.components.playercontroller ~= nil and self.inst.components.playercontroller.deployplacer ~= nil then
				if buffaction.SetActionPoint then
					buffaction:SetActionPoint(self.inst.components.playercontroller.deployplacer:GetPosition())--获取Placer的坐标点，方便几何定位
				end
				-- buffaction.pos = self.inst.components.playercontroller.deployplacer:GetPosition()--获取Placer的坐标点，方便几何定位
			end
		end
		if oldDoAction ~= nil then
			oldDoAction(self,buffaction,...)
		end
	end
end)

modimport("scripts/decoration_modframework.lua")--动作框架
modimport("scripts/decoration_minisign.lua")--兼容小木牌