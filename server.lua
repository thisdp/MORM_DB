importCache = nil
importTimer = nil

function import()
	if not importCache then
		local classFile = fileOpen("classlib.lua",true)
		local classStr = fileRead(classFile,fileGetSize(classFile))
		fileClose(classFile)
		importCache = classStr
		importTimer = setTimer(function() importCache = nil end,1000,1) --Clear cache
	end
	return importCache
end


fnc,err = loadstring(import())
if err then print(err) return end
fnc()

--------------------Custom Class
class "account" {
	uid = "uint32",
	username = "char[32]",
	password = "char[256]",
	constructor = function(self,data)
		if type(data) ~= "table" then return end
		for k,v in pairs(data) do
			self[k] = v
		end
	end;
}

class "vehicle" {
	id = "uint32",
	model = "uint32",
	x = "float",
	y = "float",
	z = "float",
	onCreate = function(self)
		self.element = createVehicle(self.model,self.x,self.y,self.z)
	end;
	onSave = function(self)
		self.x,self.y,self.z = getElementPosition(self.element)
	end;
}

veh = vehicle{
	id = 1;
}

db = morm:Open("sqlite","test.db")
db:Create(vehicle):Query()
db:Find(veh):Query(-1,function()
	veh:onCreate()
end)
setTimer(function()
	veh:onSave()
	db:Update(veh):Query(-1)
	print("saved")
end,5000,1)
iprint(veh)
--查询
--db:Select("*"):From("account"):Where("uid",123):Query()