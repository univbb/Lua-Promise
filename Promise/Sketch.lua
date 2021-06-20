-- Example
local Promise = require('Promise')

local promise = Promise.new(function(resolve, reject) 
  resolve()
end) -- Promise.Resolve(...) or Promise.Reject(...)

-- Giving it some thens & catches
promise:Then(function() 
  print('Promise resolved!')
end):Catch(function() 
  print('Oh no! Promise was rejected')
end)

-- Initializing promise
promise:Start() -- Promise:Go()
