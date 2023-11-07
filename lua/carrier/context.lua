local function get_current_buffer_text()
    -- Get the current buffer ID
    local buf_id = vim.api.nvim_get_current_buf()
    -- Get all lines from the current buffer
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    -- Concatenate all lines into a single string
    return table.concat(lines, "\n")
end

return {
    get_current_buffer_text = get_current_buffer_text,
}
