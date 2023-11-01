local config = require("carrier.config")

local Carrier = {}

function Carrier.setup(opts)
    config.setup(opts)
end

return Carrier
