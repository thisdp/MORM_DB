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

--------------------
ac = account{
	uid=1,
	username="tt",
	password="xx",
}

ac2 = account{
	uid=12,
	username="ttx",
	password="xxw",
}


db = morm:Open("sqlite","test.db")
--[[db:Create(account):Query()
db:Create(ac):Query()
db:Update(ac2):Query()]]


ac3 = account{
	uid=12,
}
ac2 = account{
	uid=1,
}
local list = {ac3,ac2}

db:Find(list):Query()

iprint(list)
--查询
--db:Select("*"):From("account"):Where("uid",123):Query()