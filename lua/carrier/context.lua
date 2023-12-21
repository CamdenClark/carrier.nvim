local ts = require("vim.treesitter")

local function get_current_buffer_text()
    -- Get the current buffer ID
    local buf_id = vim.api.nvim_get_current_buf()
    -- Get all lines from the current buffer
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    -- Concatenate all lines into a single string
    return table.concat(lines, "\n")
end

local function get_recent_buffers_text()
    local recent_buffers_text = ""
    local recent_buffers = vim.fn.getbufinfo({ buflisted = 1 })
    local max_buffers = math.min(#recent_buffers, 5)
    for i = 1, max_buffers do
        local buf_id = recent_buffers[i].bufnr
        local buffer_name = vim.fn.bufname(buf_id)
        -- Skip if buffer name matches 'carrier log'
        if buffer_name ~= "carrier log" then
            local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
            local buffer_text = table.concat(lines, "\n")
            recent_buffers_text = recent_buffers_text .. "[" .. buffer_name .. "]\n" .. buffer_text .. "\n"
        end
    end
    return recent_buffers_text
end

local function get_largest_direct_descendant_at_cursor()
    local cursor = vim.api.nvim_win_get_cursor(0) -- Get the current cursor position (0 indicating the current window)
    local row, col = cursor[1] - 1, cursor[2] -- Adjust the row to 0-based indexing
    local bufnr = vim.api.nvim_get_current_buf()
    local success, parser = pcall(ts.get_parser, bufnr)
    if not success or not parser then
        return
    end

    local tree = parser:parse()[1]
    local root = tree:root()
    local node = root:named_descendant_for_range(row, col, row, col)

    if not node then
        return
    end

    -- Walk up the tree until we find a node that is a direct child of the root node
    while node:parent() and node:parent() ~= root do
        node = node:parent()
    end

    local start_row, start_col, end_row, end_col = node:range()
    local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row - 1, end_col - 1, {})
    local node_text = table.concat(lines, "\n")

    return node_text
end

return {
    get_current_buffer_text = get_current_buffer_text,
    get_recent_buffers_text = get_recent_buffers_text,
    get_largest_direct_descendant_at_cursor = get_largest_direct_descendant_at_cursor,
}
