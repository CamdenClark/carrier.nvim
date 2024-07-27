local M = {}

local providers = {
    "deepseek",
}

local defaults = {
    provider = "deepseek",
    config = {
        api_key = vim.env.DEEPSEEK_API_KEY,
    },
}

M.options = {}

function M.setup(options)
    M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M
