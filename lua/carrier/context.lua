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
        local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
        local buffer_text = table.concat(lines, "\n")
        recent_buffers_text = recent_buffers_text .. "[" .. buffer_name .. "]\n" .. buffer_text .. "\n"
    end
    return recent_buffers_text
end

return {
    get_current_buffer_text = get_current_buffer_text,
    get_recent_buffers_text = get_recent_buffers_text,
}
