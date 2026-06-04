--[[
-----actions-----自定义动作
{
	id,--动作ID
	str,--动作显示名字
	fn,--动作执行函数
	actiondata,--其他动作数据，诸如strfn、mindistance等，可参考actions.lua
	state,--关联SGstate,可以是字符串或者函数
	canqueuer,--兼容排队论 allclick为默认，rightclick为右键动作
}
-----component_actions-----动作和组件绑定
{
	type,--动作类型
		*SCENE--点击物品栏物品或世界上的物品时执行,比如采集
		*USEITEM--拿起某物品放到另一个物品上点击后执行，比如添加燃料
		*POINT--装备某手持武器或鼠标拎起某一物品时对地面执行，比如植物人种田
		*EQUIPPED--装备某物品时激活，比如装备火把点火
		*INVENTORY--物品栏右键执行，比如吃东西
	component,--绑定的组件
	tests,--尝试显示动作，可写多个绑定在同一个组件上的动作及尝试函数
}
-----old_actions-----修改老动作
{
	switch,--开关，用于确定是否需要修改
	id,--动作ID
	actiondata,--需要修改的动作数据，诸如strfn、fn等，可不写
	state,--关联SGstate,可以是字符串或者函数
}
--]]

--自定义动作
local actions = {
	----------------------------SCENE点击物品----------------------------
	{
		id = "RETRIEVEDECORATION", --取回装饰品
		str = STRINGS.ACTIONS.DISMANTLE or STRINGS.ACTIONS.RETRIEVEDECORATION,
		fn = function(act)
			if act.doer ~= nil and act.doer:HasTag("item_decorator") and act.target ~= nil and act.target:HasTag("decorationitem") then
				local pt = act.target:GetPosition()
				--原本可堆叠的，一般不会有什么特别的参数，直接生成个新的
				if act.target.once_stackable then
					local newitem = SpawnPrefab(act.target.prefab, act.target.skinname, act.target.skin_id, nil)
					if newitem then
						--同步新鲜度
						if act.target.components.perishable then
							newitem.components.perishable.perishremainingtime = act.target.components.perishable.perishremainingtime
						end
						if act.doer.components.inventory ~= nil and newitem.components.inventoryitem ~= nil then
							act.doer.components.inventory:GiveItem(newitem, nil, pt)
						else
							newitem.Transform:SetPosition(pt:Get())
						end
						act.target:Remove()
						return true
					end
				elseif act.doer.components.inventory ~= nil and act.target.components.inventoryitem ~= nil then
					-- 取回时恢复原始腐烂速率倍率
					if act.target._decoration_old_perish_mult ~= nil
						and act.target.components.perishable then
						act.target.components.perishable:SetLocalMultiplier(
							act.target._decoration_old_perish_mult)
						act.target._decoration_old_perish_mult = nil
					end
					act.target.components.inventoryitem.canbepickedup=true
					act.target:RemoveTag("decorationitem")--已放置的装饰品标签
					act.doer.components.inventory:GiveItem(act.target,nil,pt)
					return true
				end
			end
		end,
		state = "doshortaction",
		canqueuer = "rightclick",--兼容排队论
		actiondata = {
			priority=10,
		},
	},
	----------------------------POINT点击物品----------------------------
	{
		id = "DEPLOYDECORATION", --放置装饰品
		str = STRINGS.ACTIONS.DEPLOY.PORTABLE or STRINGS.ACTIONS.DEPLOYDECORATION,
		fn = function(act)
			if act.doer ~= nil and act.doer:HasTag("item_decorator") and act.invobject ~= nil and act.invobject:HasTag("isdecorationitem") then
				local act_pos = act:GetActionPoint()
				local container = act.doer.components.inventory or act.doer.components.container
				local obj = container ~= nil and container:RemoveItem(act.invobject) or nil
				if obj ~= nil and obj.DecorationDeploy ~= nil then
					obj:DecorationDeploy(act_pos, act.doer)
					return true
				end
			end
		end,
		state = "doshortaction",
		canqueuer = "allclick",--"rightclick",--兼容排队论
		actiondata = {
			priority=10,
		},
	},
}

--动作与组件绑定
local component_actions = {
	{
		type = "SCENE",
		component = "inventoryitem",
		tests = {
			{
				action = "RETRIEVEDECORATION",--取回装饰品
				testfn = function(inst,doer,actions,right)
					return right and inst:HasTag("decorationitem") and doer:HasTag("item_decorator")
				end,
			},
		},
	},
	{
		type = "POINT",
		component = "inventoryitem",
		tests = {
			{
				action = "DEPLOYDECORATION",--种下装饰品
				testfn = function(inst, doer, pos, actions, right, target)
					if inst.replica.equippable ~= nil and inst.replica.equippable:IsEquipped() then
						return false
					end
					if doer.components.playercontroller ~= nil and doer.components.playercontroller.deployplacer ~= nil then
						pos = doer.components.playercontroller.deployplacer:GetPosition()--获取Placer的坐标点，方便几何定位
					end
					return right and inst:HasTag("isdecorationitem") and doer:HasTag("item_decorator") and DecorationCanDeployAtPoint(pos, inst)
				end,
			},
		},
	},
}

--修改老动作
local old_actions = {
	
}

return {
	actions = actions,
	component_actions = component_actions,
	old_actions = old_actions,
}