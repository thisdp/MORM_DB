importCache = nil
importTimer = nil

function import()
	if not importCache then
		local classFile = fileOpen("classlib.lua",true)
		local classStr = fileRead(classFile,fileGetSize(classFile))
		fileClose(classFile)
		importCache = classStr
		setTimer(function() importCache = nil end,1000,1) --Clear cache
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
		for k,v in pairs(data) do
			self[k] = v
		end
	end;
}

--------------------
db = morm:Open("sqlite","test.db")
db:Create("newName",account):Query()

db:Select("*"):From("account"):Where("uid",123):Query(1000,function(self,data)
	iprint(data)
end)

local acc = account{
	uid = 123,
}
db:Table(account):Update(acc):Query()