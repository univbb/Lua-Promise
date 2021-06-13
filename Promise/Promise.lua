--[[
  @name Promise.lua
  @author univb
  @since December 4th, 2020
  @desc Promise class implemented on Lua, based on JavaScript Promise class

  @constructor
  -- Promise.new(callback: Function)

  @static
  -- Promise.Reject(... -> args): Promise
  -- Promise.Resolve(... -> args): Promise
  -- Promise.All(promises: Table): Promise
  -- Promise.Promisify(func: Function, ... -> args): Promise
  
  @methods
  -- Promise:Then(callback: Function): table
  -- Promise:Catch(callback: Function): table
  -- Promise:Finally(callback: Function): table
  
  -- Promise:Await(): table
  -- Promise:Start(): void
  -- Promise:GetStatus(): boolean
  -- Promise:Cancel(): void
]]
-- * Priority
local Status = {
  ['Rejected'] = 'Rejected',
  ['Resolved'] = 'Resolved',
  ['Pending']  = 'Pending',

  ['Cancelled']  = 'Cancelled',
}

local Errors = {
  ['UnhandledPromiseRejection'] = {
    Name = 'UnhandledPromiseRejection',
    Desc = 'Promise rejected without :Catch'
  }
}

-- * Class
local Promise = {}
Promise.Type = 'Promise'
Promise.__index = Promise


-- * constructor
function Promise.new(callback)
  assert(callback, 'Promise callback must exists!')

  local self = setmetatable({
    Callback = callback,
    Executed = false,

    Status = Status.Pending
  }, Promise)

  self._thens = {}
  self._catches = {}
  self._finally = {}
  self._can = true


  return self
end


-- * static / utility
function Promise.all(promises_tab)
  local promises = {}
  local rejected = false

  for _,promise in next,promises_tab do
    if(promise.Type) then
      if(promise.Type == 'Promise') then
        if(promise.Executed) then return end
        if(rejected) then break end

        local ps = promise:Then(function(...) 
          promises[promise] = {...}
        end):Catch(function() 
          rejected = true
        end)

        ps:Start()
        ps:Await()
      end
    end
  end

  return Promise.new(function(resolve, reject) 
    if(rejected) then
      reject()
    else
      resolve(promises)
    end
  end)
end


function Promise.resolve(...)
  local args = {...}

  return Promise.new(function(resolve, reject) 
    resolve(unpack(args))
  end)
end


function Promise.reject(...)
  local args = {...}

  return Promise.new(function(resolve, reject) 
    reject(unpack(args))
  end)
end


function Promise.promisify(func, ...)
  local args = {...}

  return Promise.new(function(resolve, reject) 
    local result = func(unpack(args))

    if(result) then
      resolve(result)
    else
      reject(result)
    end
  end)
end


-- * methods
function Promise:Cancel()
  self.Status = Status.Cancelled
end


function Promise:Then(callback)
  table.insert(self._thens, function(...)
    callback(...)
    return self._res
  end)
  return self
end


function Promise:Catch(callback)
  table.insert(self._catches, function(...)
    callback(...)
    return self._err
  end)
  return self
end


function Promise:Finally(callback)
  table.insert(self._finally, callback)
  return self
end


function Promise:_createError(errText)
  error(errText)
end


function Promise:_rejectAll(...)
  if(not self._can) then return end
  if(#self._catches == 0) then
    self:_createError(Errors.UnhandledPromiseRejection.Name .. ': "' .. 'No "Promise::Catch" found' .. '"')

    return
  end
  
  local args = {...}
  local thread = coroutine.wrap(function()
    for _,callback in next,self._catches do
      return callback(unpack(args))
    end
  end)

  self._can = false

  return thread()
end


function Promise:_resolveAll(...)
  if(not self._can) then return end

  local args = {...}
  local thread = coroutine.wrap(function()
    for _,callback in next,self._thens do
      callback(unpack(args))
    end
  end)

  self._can = false
  
  return thread()
end


function Promise:_goFinally()
  local thread = coroutine.wrap(function() 
    for _,callback in next,self._finally do
      callback()
    end
  end)

  thread()
end


function Promise:GetStatus()
  return self.Status
end


function Promise:await()
  repeat
  until self.Status == Status.Resolved or self.Status == Status.Rejected

  return unpack(self._resolveValues or self._rejectValues)
end


function Promise:Go()
  if(self.Executed) then return end
  if(self.Status == Status.Cancelled) then 
    self:_finally()
    return
  end

  self.Executed = true

  local err = xpcall(function()
    self._res = self.Callback(function(...)
      if(self.Status == Status.Rejected or self.Status == Status.Resolved) then return end

      self._resolveValues = {...}
      self.Status = Status.Resolved
      return self:_resolveAll(...)
    end, function(...)
      if(self.Status == Status.Rejected or self.Status == Status.Resolved) then return end

      self._rejectValues = {...}
      self.Status =  Status.Rejected
      return self:_rejectAll(...)
    end)
  end, function(err) 
    self._err = err

    if(#self._catches == 0) then
      print(Errors.UnhandledPromiseRejection.Name .. ': "' .. self._err .. '"')
    else
      self:_rejectAll(err)
    end
    self.Status =  Status.Rejected
  end)

  if(self.Status ~= Status.Pending) then
    self:_goFinally()
  end

  return self
end


-- * Alias
-- * constructor & methods
Promise.New = Promise.new
Promise.Await = Promise.await
Promise.Start = Promise.Go
Promise.Promisify = Promise.promisify

-- * static
Promise.All = Promise.all
Promise.Resolve = Promise.resolve
Promise.Reject = Promise.reject


return Promise
