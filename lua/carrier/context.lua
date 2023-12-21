local ts = require("vim.treesitter")
local ts_query = require("vim.treesitter.query")

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

local function get_current_root_form()
    local bufnr = vim.api.nvim_get_current_buf()
    local parser = ts.get_parser(bufnr)
    -- We should perform a check here to make sure the parser is actually available.
    if not parser then
        vim.api.nvim_err_writeln("Tree-sitter parser not available for current buffer.")
        return
    end
    local tree = parser:parse()[1] -- Get the first syntax tree (which is the root for most purposes)
    local root = tree:root()
    local start_row, start_col, end_row, end_col = root:range()
    print(start_row, start_col, end_row, end_col)

    -- Using nvim_buf_get_text because it respects start and end column range,
    -- unlike nvim_buf_get_lines which gets full lines
    local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row - 1, end_col - 1, {})
    local root_form = table.concat(lines, "\n")
    return root_form
end

return {
    get_current_buffer_text = get_current_buffer_text,
    get_recent_buffers_text = get_recent_buffers_text,
    get_current_root_form = get_current_root_form,
}
