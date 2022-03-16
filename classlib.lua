--classlib.lua
local loadstring = loadstring
-------OOP
local getmetatable = getmetatable
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local _call = call
local setfenv = setfenv
local function call(...)
	local _source = source
	local retValue = {_call(...)}
	source = _source
	return unpack(retValue)
end
-------Utils
local strToIntCache = {
	["vector2"]=2,
	["vector3"]=3,
	["vector4"]=4,
}
oopUtil = {
	classReg = {},
	classMetaReg = {},
	instanceReg = setmetatable({},{__mode="kv"}),
	eventHandler = {},
	transfromEventName = function(eventName,isReverse)
		return isReverse and (eventName:sub(3,3):lower()..eventName:sub(4)) or ("on"..eventName:sub(1,1):upper()..eventName:sub(2))
	end,
	getVectorType = function(vec)
		if type(vec) == "userdata" then
			local typeName = getUserdataType(vec)
			if typeName == "vector" then
				return strToIntCache[typeName]
			end
		end
		return false
	end,
	deepCopyWithMeta = function(obj)
		local function Func(obj)
			if type(obj) ~= "table" then return obj end
			local NewTable = {}
			for k,v in pairs(obj) do
				NewTable[Func(k)] = Func(v)
			end
			return setmetatable(NewTable,getmetatable(obj))
		end
		return Func(obj)
	end,
	deepCopy = function(obj)
		local function Func(obj)
			if type(obj) ~= "table" then return obj end
			local NewTable = {}
			for k,v in pairs(obj) do
				NewTable[Func(k)] = Func(v)
			end
			return NewTable
		end
		return Func(obj)
	end,
	shallowCopy = function(obj)
		local InTable = {}
		for k,v in pairs(obj) do
			InTable[k] = v
		end
		return InTable
	end,
	assimilate = function(t1,t2,except)
		if not t1 or not t2 then return end
		local exceptTable = {}
		if type(except) == "tabe" then
			for i=1,#except do
				exceptTable[ except[i] ] = true
			end
		end
		for k,v in pairs(t2) do
			if not exceptTable[k] then
				t1[k] = v
			end
		end
	end,
	spreadFunctionsForClass = function(class,classTemplate)
		oopUtil.assimilate(class,classTemplate,{"expose","constructor","public"})
		oopUtil.assimilate(class,classTemplate.public)
	end,
	configToSql = function(self,dbType)
		local strTable = {}
		for columnName,dType in pairs(self) do
			strTable[#strTable+1] = "`"..columnName.."` "..(sqlDataType[dType] or dType)
		end
		return table.concat(strTable,",")
	end,
}

function class(name) return function(classTable)
	oopUtil.classReg[name] = classTable	--register class with class name
	oopUtil.classMetaReg[name] = {__index = {}}	--register class metatable with class name
	local meta = {
		__call = function(classTemplate,...)
			local newInstance = {}
			setmetatable(newInstance,oopUtil.classMetaReg[name])
			if classTemplate.constructor then classTemplate.constructor(newInstance,...) end
			return newInstance
		end,
	}
	if classTable.extend then
		if not classTable.public then classTable.public = {} end
		if type(classTable.extend) ~= "table" then
			local extendClass = oopUtil[classTable.extend]
			for extKey,extFunction in pairs(extendClass.public or {}) do
				if not classTable.public[extKey] then classTable.public[extKey] = extFunction end	--Don't overwrite child's function when copying parent's functions
			end
		else
			for key,extend in ipairs(classTable.extend) do
				local extendClass = oopUtil[extend]
				for extKey,extFunction in pairs(extendClass.public or {}) do
					if not classTable.public[extKey] then classTable.public[extKey] = extFunction end	--Don't overwrite child's function when copying parent's functions
				end
			end
		end
	end
	if classTable.inject then
		for theType,space in pairs(classTable.inject) do
			local injectedData = oopUtil[theType]
			if not injectedData.public then injectedData.public = {} end
			if not injectedData.default then injectedData.default = {} end
			for name,fnc in pairs(space.default or {}) do
				injectedData.default[name] = fnc
			end
			for name,fnc in pairs(space.public or {}) do
				injectedData.public[name] = fnc
			end
		end
	end
	meta.__index = {class=name}
	setmetatable(classTable,meta)
	oopUtil.spreadFunctionsForClass(oopUtil.classMetaReg[name].__index,classTable)
	oopUtil.classMetaReg[name].__index.class = name
	if not classTable.expose then
		_G[name] = classTable
	elseif oopUtil.classMetaReg[classTable.expose] then
		oopUtil.classMetaReg[classTable.expose].__index[name] = function(self,...) return classTable(...) end
	end
end
end
oopUtil.class = class

--Types:
--public: Will inherit
sqlDataType = {
	integer = "int",
	int = "int",
	int8 = "tinyint",
	int16 = "smallint",
	int24 = "mediumint",
	int32 = "int",
	int64 = "bigint",
	uint = "int unsigned",
	uint8 = "tinyint unsigned",
	uint16 = "smallint unsigned",
	uint24 = "mediumint unsigned",
	uint32 = "int unsigned",
	uint64 = "bigint unsigned",
}

class "MORM" {
	Open = function(self,...)
		return oopUtil.classReg.DataBase(...)
	end;
}

class "TableConfig" {
	expose = "MORM",
	constructor = function(self,config)
		self.config = config and oopUtil.deepCopy(config) or {}
		self.name = config.class or nil
	end,
	setName = function(self,tableName)
		if type(tableName) ~= "string" then return outputDebugString("@setName at argument 1, expect a string got "..type(tableName),3) end
		self.name = tableName
		return self
	end,
	addColumn = function(self,columnName,dataType)
		if type(columnName) ~= "string" then return outputDebugString("@addColumn at argument 1, expect a string got "..type(columnName),3) end
		if type(dataType) ~= "string" then return outputDebugString("@addColumn at argument 2, expect a string got "..type(dataType),3) end
		local dType = string.lower(dataType)
		self.config[columnName] = dType
		return self
	end,
	toSql = function(self,dbType)
		local strTable = {}
		for columnName,dType in pairs(self.config) do
			if type(dType) == "string" then
				strTable[#strTable+1] = "`"..columnName.."` "..(sqlDataType[dType] or dType)
			end
		end
		return table.concat(strTable,",")
	end,
}

class "DataBase" {
	expose = "MORM",
	constructor = function(self,dbType,...)
		self.db = dbConnect(dbType,...)
		self.dbString = {}
		self.dbType = dbType
	end;
	AutoMigrate = function(self,...)
		if select("#",...) == 2 then
			local first,second = ...
			--"tableName", classTemplate
			if type(first) == "string" then
				-- to do
			end
		end
	end;
	Create = function(self,...)
		if select("#",...) == 1 then
			local template = ...
			if not(type(template) == "table" and template.class) then outputDebugString("@Create at argument 1, expect a Class/TableConfig got "..type(template),3) return false end
			if template.class == "TableConfig" then
				--if table name is not specified
				if not self.dbString.table then
					if not(type(template.name) == "string") then outputDebugString("@Create, table name is not specified",3) return false end
				end
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Create Table If Not Exists `??` (??)",self.dbString.table or template.name,template:toSql(self.dbType))
			else
				--if table name is not specified
				if not self.dbString.table then
					if not(type(template.class) == "string") then outputDebugString("@Create, table name is not specified",3) return false end
				end
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Create Table If Not Exists `??` (??)",self.dbString.table or template.class,oopUtil.configToSql(template,self.dbType))
			end
		else
			local tableName,template = ...
			if not(type(template) == "table") then outputDebugString("@Create at argument 1, expect a Class/TableConfig/table got "..type(template),3) end
			if template.class == "TableConfig" then
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Create Table If Not Exists `??` (??)",self.dbString.table or tableName,template:toSql(self.dbType))
			else
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Create Table If Not Exists `??` (??)",self.dbString.table or tableName,oopUtil.configToSql(template,self.dbType))
			end
		end
		return self
	end;
	Select = function(self,selectColumn)
		self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Select ?? ",selectColumn or "*")
		return self
	end;
	From = function(self,fromTable)
		self.dbString[#self.dbString+1] = dbPrepareString(self.db,"From `??` ",fromTable)
		return self
	end;
	Where = function(self,columnName,value)
		self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Where `??` = ? ",columnName,value)
		return self
	end;
	First = function(self,...)
	
	end;
	Update = function(self,...)
		local argCount = select("#",...)
		if argCount == 2 then
			local key,value = ...
			if type(value) == "table" then
				local tableNameOrTemplate,updateTable = ...
				if not (type(tableNameOrTemplate) == "string" or (type(tableNameOrTemplate) == "table" and tableNameOrTemplate.class)) then outputDebugString("@Update at argument 1, expect a Class/TableConfig/string got "..type(tableNameOrTemplate),3) end
				if not (type(updateTable) == "table") then outputDebugString("@Update at argument 2, expected a table got "..type(updateTable),3) return false end
				if not self.dbString.table then
					if type(tableNameOrTemplate) == "string" then
						self.dbString.table = tableNameOrTemplate
					elseif tableNameOrTemplate.class == "TableConfig" then
						self.dbString.table = tableNameOrTemplate.name
					else
						self.dbString.table = tableNameOrTemplate.class
					end
				end	--Skip if table is already specified
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update `??` SET ",self.dbString.table)
				for key,value in pairs(updateTable) do
					self.dbString[#self.dbString+1] = dbPrepareString(self.db,"`??` = ?",key,value)
				end
			else
				if not (type(key) == "string") then outputDebugString("@Update at argument 1, expected a string got "..type(key),3) return false end
				if not self.dbString.table then outputDebugString("@Update, table name is not specified",3) return false end
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update `??` SET `??` = ? ",self.dbString.table,key,value)
			end
		elseif argCount == 3 then
			local tableNameOrTemplate,key,value = ...
			if not (type(tableNameOrTemplate) == "string" or (type(tableNameOrTemplate) == "table" and tableNameOrTemplate.class)) then outputDebugString("@Update at argument 1, expect a Class/TableConfig/string got "..type(tableNameOrTemplate),3) end
			if not (type(key) == "string") then outputDebugString("@Update at argument 2, expected a string got "..type(key),3) return false end
			if not self.dbString.table then
				if type(tableNameOrTemplate) == "string" then
					self.dbString.table = tableNameOrTemplate
				elseif tableNameOrTemplate.class == "TableConfig" then
					self.dbString.table = tableNameOrTemplate.name
				else
					self.dbString.table = tableNameOrTemplate.class
				end
			end	--Skip if table is already specified
			if not self.dbString.table then outputDebugString("@Update, table name is not specified",3) return false end
			self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update`??` SET `??` = ? ",self.dbString.table,key,value)
		elseif argCount == 1 then
			local updateTable = ...
			if not (type(updateTable) == "table") then outputDebugString("@Update at argument 1, expected a table got "..type(updateTable),3) return false end
			if not self.dbString.table then outputDebugString("@Update, table name is not specified",3) return false end
			self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update `??` SET ",self.dbString.table)
			for key,value in pairs(updateTable) do
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"`??` = ?",key,value)
			end
		end
		return self
	end;
	Insert = function(self,fromTable,...)
		if select("#",...) == 1 then
		
		else
			--local 
		end
	end;
	Delete = function(self,tableName)
		self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Drop Table If Exists ?",tableName)
		return self
	end;
	Query = function(self,timedout,callback)
		local _self = self
		if callback then
			dbQuery(function(handle)
				self = _self
				callback(self,dbPoll(handle,timedout or -1))
			end,self.db,table.concat(self.dbString))
			self.dbString = {}
			return true
		else
			local handle = dbQuery(self.db,table.concat(self.dbString))
			self.dbString = {}
			return dbPoll(handle,timedout or -1)
		end
	end;
	Raw = function(self,raw,...)
		if not(type(raw) == "string") then return outputDebugString("@Raw at argument 1, expect a string got "..type(raw),3) end
		self.dbString[#self.dbString+1] = dbPrepareString(self.db,raw,...)
		return self
	end;
	Table = function(self,tableNameOrTemplate)
		--Use this table if specified by :Table("tableName"), and this has the top priority.
		if not (type(tableNameOrTemplate) == "string" or (type(tableNameOrTemplate) == "table" and tableNameOrTemplate.class)) then outputDebugString("@Table at argument 1, expect a Class/TableConfig/string got "..type(tableNameOrTemplate),3) end
		if type(tableNameOrTemplate) == "string" then
			self.dbString.table = tableNameOrTemplate
		elseif tableNameOrTemplate.class == "TableConfig" then
			self.dbString.table = tableNameOrTemplate.name
		else
			self.dbString.table = tableNameOrTemplate.class
		end
		return self
	end;
	Alert = function(self,...)
	
	end;
	Drop = function(self,...)
	
	end;
	Change = function(self,...)
	
	end;
	Add = function(self,...)
	
	end;
	Modify = function(self,...)
	
	end;
}
morm = MORM()

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
tConf = morm:TableConfig(account)
db:Create("newName",tConf):Query()

db:Select("*"):From("account"):Where("uid",123):Query(1000,function(self,data)
	iprint(data)
end)

local acc = account{
	uid = 123,
}
db:Table(tConf):Update(acc):Query()