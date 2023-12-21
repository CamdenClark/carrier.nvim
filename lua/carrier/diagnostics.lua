-- Function to get all diagnostics for the current buffer
local function get_current_buffer_diagnostics()
    local buffer_id = 0 -- 0 refers to the current buffer
    -- Fetch all diagnostics for the current buffer
    local diagnostics = vim.diagnostic.get(buffer_id)
    return diagnostics
end

local function get_diagnostic_under_cursor()
    local pos = vim.api.nvim_win_get_cursor(0) -- Get the current cursor position
    local row = pos[1] - 1 -- Adjust row for 0-indexing
    local col = pos[2] -- Column is already 0-indexed
    -- Fetch diagnostics for the current buffer and position
    local diagnostics = vim.diagnostic.get(0, { lnum = row, col = col })
    return diagnostics
end

return {
    get_current_buffer_diagnostics = get_current_buffer_diagnostics,
    get_diagnostic_under_cursor = get_diagnostic_under_cursor,
}
