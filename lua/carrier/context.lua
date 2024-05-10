local function get_last_non_carrier_buffer_and_pos()
    local bufinfo = vim.fn.getbufinfo({ buflisted = 1 })
    table.sort(bufinfo, function(a, b)
        return a.lastused > b.lastused
    end)

    for _, buf in ipairs(bufinfo) do
        -- Check if buffer is loaded and not a carrier log buffer
        if vim.api.nvim_buf_is_loaded(buf.bufnr) and not buf.name:match("carrier log") then
            local last_pos = { buf.lnum, 0 } or { 1, 0 } -- Fallback to start of buffer if not found
            return buf.bufnr, last_pos
        end
    end
    return nil, nil
end

local function get_buffers_content_summary()
    local buffers_summary = ""
    local total_length = 0
    local max_content_length = 10000
    local TOTAL_MAX_LENGTH = 20000

    -- Get buffer info for all listed buffers sorted by last change time in descending order
    local bufinfo = vim.fn.getbufinfo({ buflisted = 1 })
    table.sort(bufinfo, function(a, b)
        return a.lastused > b.lastused
    end)
    local current_buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1]

    for _, buf in ipairs(bufinfo) do
        if buf.name and buf.name ~= "carrier log" and vim.api.nvim_buf_is_loaded(buf.bufnr) then
            local lines = vim.api.nvim_buf_get_lines(buf.bufnr, 0, -1, false)
            if buf.bufnr == current_buf then
                local cursor_line = lines[row] or ""
                lines[row] = cursor_line .. " [cursor]"
            end
            local content = table.concat(lines, "\n")
            local content_length = #content

            if content_length <= max_content_length and (total_length + content_length) < TOTAL_MAX_LENGTH then
                local header = buf.name .. "\n"
                local header_length = #header
                if (total_length + header_length) >= TOTAL_MAX_LENGTH then
                    break
                end

                buffers_summary = buffers_summary .. header .. content .. "\n\n"
                total_length = total_length + content_length + header_length
            end
        end
        if total_length >= TOTAL_MAX_LENGTH then
            break
        end
    end

    return buffers_summary
end

local function get_largest_direct_descendant_at_pos(bufnr, row, col)
    local success, parser = pcall(require("vim.treesitter").get_parser, bufnr)
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

-- And you can modify the original get_largest_direct_descendant_at_cursor to use this new function
local function get_largest_direct_descendant_at_cursor()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local bufnr = vim.api.nvim_get_current_buf()

    return get_largest_direct_descendant_at_pos(bufnr, row, col)
end

return {
    get_largest_direct_descendant_at_cursor = get_largest_direct_descendant_at_cursor,
    get_buffers_content_summary = get_buffers_content_summary,
    get_last_non_carrier_buffer_and_pos = get_last_non_carrier_buffer_and_pos,
}
