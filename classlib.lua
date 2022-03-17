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
	splitKeyValue = function(theTable)
		local keyTable = {}
		local valueTable = {}
		for key,value in pairs(theTable) do
			keyTable[#keyTable+1] = key
			valueTable[#valueTable+1] = value
		end
		return keyTable,valueTable
	end;
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
			if type(dType) == "string" then
				strTable[#strTable+1] = "`"..columnName.."` "..(sqlDataType[dType] or dType)
			end
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
	oopUtil.classMetaReg[name].__index.instance = true
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
		local tableName,template
		if select("#",...) == 1 then
			template = ...
			if not(type(template) == "table" and template.class) then outputDebugString("@Create at argument 1, expect a Class/Instance got "..type(template),3) return false end
			if not self.dbString.table then --if table name is not specified
				if not(type(template.class) == "string") then outputDebugString("@Create, table name is not specified",3) return false end
			end
			tableName = self.dbString.table or template.class
		else
			tableName,template = ...
			if not(type(tableName) == "string") then outputDebugString("@Create at argument 1, expect a string got "..type(tableName),3) end
			if not(type(template) == "table") then outputDebugString("@Create at argument 2, expect a Class/table got "..type(template),3) end
			tableName = self.dbString.table or tableName
		end
		if template.instance then	--If is instance, just insert
			self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Insert Into `??` ",tableName)
			local ks,vs = oopUtil.splitKeyValue(template)
			local keys,values = {},{}
			for i=1,#ks do
				keys[#keys+1] = dbPrepareString(self.db,"`??`",ks[i])
				values[#values+1] = dbPrepareString(self.db,"?",vs[i])
			end
			self.dbString[#self.dbString+1] = "("..table.concat(keys,",")..") Values ("..table.concat(values,",")..")"
		else
			self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Create Table If Not Exists `??` (??)",self.dbString.table or template.class,oopUtil.configToSql(template,self.dbType))
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
		if argCount == 1 then
			local template = ...
			if not(type(template) == "table") then outputDebugString("@Update at argument 1, expect a Class/Instance got "..type(template),3) return false end
			if not self.dbString.table then
				if not(type(template.class) == "string") then outputDebugString("@Update, table name is not specified",3) return false end
				self.dbString.table = template.class
			end
			self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update `??` SET ",self.dbString.table)
			local kvPair = {}
			for key,value in pairs(template) do
				kvPair[#kvPair+1] = dbPrepareString(self.db," `??` = ? ",key,value)
			end
			self.dbString[#self.dbString+1] = table.concat(kvPair,",")
		elseif argCount == 2 then
			local key,value = ...
			if type(value) == "table" then
				local tableNameOrTemplate,template = ...
				if not (type(tableNameOrTemplate) == "string" or (type(tableNameOrTemplate) == "table" and tableNameOrTemplate.class)) then outputDebugString("@Update at argument 1, expect a Class/string got "..type(tableNameOrTemplate),3) end
				if not(type(template) == "table") then outputDebugString("@Update at argument 2, expect a table/Instance got "..type(template),3) return false end			
				if not self.dbString.table then
					if type(tableNameOrTemplate) == "string" then
						self.dbString.table = tableNameOrTemplate
					else
						self.dbString.table = tableNameOrTemplate.class
					end
				end	--Skip if table is already specified
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update `??` SET ",self.dbString.table)
				local kvPair = {}
				for key,value in pairs(template) do
					kvPair[#kvPair+1] = dbPrepareString(self.db," `??` = ? ",key,value)
				end
				self.dbString[#self.dbString+1] = table.concat(kvPair,",")
			else
				if not (type(key) == "string") then outputDebugString("@Update at argument 1, expected a string got "..type(key),3) return false end
				if not self.dbString.table then outputDebugString("@Update, table name is not specified",3) return false end
				self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update `??` SET `??` = ? ",self.dbString.table,key,value)
			end
		elseif argCount == 3 then
			local tableNameOrTemplate,key,value = ...
			if not (type(tableNameOrTemplate) == "string" or (type(tableNameOrTemplate) == "table" and tableNameOrTemplate.class)) then outputDebugString("@Update at argument 1, expect a Class/string got "..type(tableNameOrTemplate),3) end
			if not (type(key) == "string") then outputDebugString("@Update at argument 2, expected a string got "..type(key),3) return false end
			if not self.dbString.table then
				if type(tableNameOrTemplate) == "string" then
					self.dbString.table = tableNameOrTemplate
				else
					self.dbString.table = tableNameOrTemplate.class
				end
			end	--Skip if table is already specified
			if not self.dbString.table then outputDebugString("@Update, table name is not specified",3) return false end
			self.dbString[#self.dbString+1] = dbPrepareString(self.db,"Update`??` SET `??` = ? ",self.dbString.table,key,value)
		end
		return self
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
			print(table.concat(self.dbString))
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
		if not (type(tableNameOrTemplate) == "string" or (type(tableNameOrTemplate) == "table" and tableNameOrTemplate.class)) then outputDebugString("@Table at argument 1, expect a Class/string got "..type(tableNameOrTemplate),3) end
		self.dbString.table = (type(tableNameOrTemplate) == "string") and tableNameOrTemplate or tableNameOrTemplate.class
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
