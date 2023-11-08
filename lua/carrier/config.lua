local M = {}

local defaults = {
    model = "gpt-3.5-turbo",
    temperature = 1,
    url = "https://api.openai.com/v1/chat/completions",
    headers = {
        Authorization = "Bearer " .. (vim.env.OPENAI_API_KEY or ""),
        Content_Type = "application/json",
    },
}

M.options = {}

function M.setup(options)
    M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

function M.switch_model(model)
    M.options.model = model
end

function M.set_temperature(temperature)
    local temp = tonumber(temperature)
    if temp == nil then
        error("Temperature setting must be a number between 0 and 2: can't interpret " .. temperature .. " as a number")
        return
    end
    if temp < 0 or temp > 2 then
        error("Temperature setting must be a number between 0 and 2")
        return
    end
    M.options.temperature = temp
end

M.setup()

return M
