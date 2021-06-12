-- Example
local Promise = require('Promise')

local promise = Promise.new(function(resolve, reject) 
  resolve()
end)

-- Initializing the promise and giving it some thens & catches
promise:Then(function() 
  print('Promise resolved!')
end):Catch(function() 
  print('Oh no! We got an reject')
end)