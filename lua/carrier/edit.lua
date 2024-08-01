local openai = require("carrier.openai")
-- local claude = require("carrier.claude")
local deepseek = require("carrier.deepseek")
local config = require("carrier.config")
local context = require("carrier.context")

local current_edit = nil

local function get_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local start_line, start_col = start_pos[2], start_pos[3]
    local end_line, end_col = end_pos[2], end_pos[3]

    local buffer = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buffer, start_line - 1, end_line, false)

    -- Modify the first line to start at the correct column
    lines[1] = lines[1]:sub(start_col)

    -- Modify the last line to end at the correct column
    lines[#lines] = lines[#lines]:sub(1, end_col - 1)

    -- Join the lines into a single string
    return start_line, start_col, end_line, end_col, table.concat(lines, "\n")
end

local function replace_selection(buffer, start_line, start_col, end_line, end_col, new_text)
    local new_lines = {}
    for line in new_text:gmatch("([^\n]*)\n?") do
        table.insert(new_lines, line)
    end
    -- Replace the first and last lines to leave the unselected text unchanged
    local old_lines = vim.api.nvim_buf_get_lines(buffer, start_line - 1, end_line, false)
    if start_col > 1 then
        new_lines[1] = old_lines[1]:sub(1, start_col) .. new_lines[1]
    end
    if end_col <= #old_lines[#old_lines] then
        new_lines[#new_lines] = new_lines[#new_lines] .. old_lines[#old_lines]:sub(end_col)
    end
    -- Set the new lines in the buffer
    vim.api.nvim_buf_set_lines(buffer, start_line - 1, end_line, false, new_lines)
end

local function accept_suggestion(buffer, col, line, suggestion)
    local new_lines = vim.split(suggestion, "\n")
    local old_lines = vim.api.nvim_buf_get_lines(buffer, line - 1, line, false)
    local old_line = old_lines[1]
    if col > 1 then
        new_lines[1] = old_line:sub(1, col) .. new_lines[1]
    end
    vim.api.nvim_buf_set_lines(buffer, line - 1, line, false, new_lines)
end

local function clear_diff_buf()
    local diff_buf = current_edit and current_edit.diff_buf
    if diff_buf then
        vim.api.nvim_buf_delete(diff_buf, { force = true })
    end
end

local function diff_lines(arr1, arr2)
    local result = {}
    local i, j = 1, 1

    while i <= #arr1 or j <= #arr2 do
        if i > #arr1 then
            table.insert(result, { { arr2[j], "diffAdded" } })
            j = j + 1
        elseif j > #arr2 then
            table.insert(result, { { arr1[i], "diffRemoved" } })
            i = i + 1
        elseif arr1[i] == arr2[j] then
            table.insert(result, { { arr1[i], "normal" } })
            i, j = i + 1, j + 1
        else
            table.insert(result, { { arr1[i], "diffRemoved" } })
            i = i + 1
            if j <= #arr2 then
                table.insert(result, { { arr2[j], "diffAdded" } })
                j = j + 1
            end
        end
    end

    return result
end

local function create_diff_buf()
    local diff_buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_option(diff_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(diff_buf, "modifiable", true)
    -- Open the new buffer in a split window
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, diff_buf)

    -- Map 'q' to reject function
    vim.api.nvim_buf_set_keymap(
        diff_buf,
        "n",
        "q",
        ":lua require'carrier.edit'.reject()<CR>",
        { noremap = true, silent = true }
    )

    return diff_buf
end

local function render_edit(buf, lines1, lines2)
    local virt_lines = diff_lines(lines1, lines2)

    -- Convert virt_lines to buffer lines
    local lines_of_diff = {}
    for _, virt_line in ipairs(virt_lines) do
        local line, hl_group = unpack(virt_line[1])
        table.insert(lines_of_diff, { line, hl_group })
    end

    -- Set the lines in the new buffer with highlights
    vim.api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        vim.tbl_map(function(item)
            return item[1]
        end, lines_of_diff)
    )
    for i, item in ipairs(lines_of_diff) do
        vim.api.nvim_buf_add_highlight(buf, -1, item[2], i - 1, 0, -1)
    end
end

local function suggest_edit()
    local buf = vim.api.nvim_get_current_buf()

    local start_line, start_col, end_line, end_col, selection = get_selection()

    local selection_lines = vim.split(selection, "\n")

    -- get edit
    local edit_prompt = vim.fn.input("Edit: ")

    local lines = { "" }

    -- Open a new buffer to render the diff
    local diff_buf = create_diff_buf()

    local on_delta = function(response)
        if current_edit and not current_edit.job.is_shutdown then
            for char in response:gmatch(".") do
                if char == "\n" then
                    lines = vim.list_extend(lines, { "" })
                    render_edit(diff_buf, selection_lines, lines)
                else
                    lines[#lines] = lines[#lines] .. char
                end
            end
        end
    end

    local on_complete = function()
        render_edit(diff_buf, selection_lines, lines)
        current_edit = {
            job = current_edit and current_edit.job,
            buf = buf,
            diff_buf = diff_buf,
            lines = lines,
            start_col = start_col,
            start_line = start_line,
            end_col = end_col,
            end_line = end_line,
        }
    end

    current_edit = {
        buf = buf,
        diff_buf = diff_buf,
        start_col = start_col,
        start_line = start_line,
        end_col = end_col,
        end_line = end_line,
    }

    current_edit.job = deepseek.stream_edit_completion(config.options, {
        selection = selection,
        edit_instruction = edit_prompt,
        buffer_content = context.get_buffers_content_summary(),
    }, on_delta, on_complete)
end

local function suggest_addition()
    local buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor_pos[1], cursor_pos[2]

    -- Get buffer content
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")
    -- Calculate the correct byte index for splitting
    local byte_index = 0
    for i = 1, row - 1 do
        byte_index = byte_index + #lines[i] + 1 -- +1 for newline
    end
    byte_index = byte_index + col

    -- Split content into prompt and suffix
    local prompt = string.sub(content, 1, byte_index)
    local suffix = string.sub(content, byte_index + 1)

    local lines = { "" }

    local diff_buf = create_diff_buf()

    local on_delta = function(response)
        if response and current_edit and not current_edit.job.is_shutdown then
            for char in response:gmatch(".") do
                if char == "\n" then
                    lines = vim.list_extend(lines, { "" })
                    render_edit(diff_buf, {}, lines)
                else
                    lines[#lines] = lines[#lines] .. char
                end
            end
        end
    end

    local on_complete = function()
        render_edit(diff_buf, {}, lines)
        current_edit = {
            buf = buf,
            diff_buf = diff_buf,
            lines = lines,
            start_col = col,
            start_line = row,
        }
    end

    current_edit = {
        buf = buf,
        diff_buf = diff_buf,
        start_col = col,
        start_line = row,
    }

    -- Call the modified deepseek.stream_fim_completion function
    current_edit.job = deepseek.stream_fim_completion(config.options, prompt, suffix, on_delta, on_complete)
end

local function accept()
    if current_edit then
        local buf = current_edit.buf
        if current_edit.end_col then
            replace_selection(
                buf,
                current_edit.start_line,
                current_edit.start_col,
                current_edit.end_line,
                current_edit.end_col,
                table.concat(current_edit.lines, "\n")
            )
        else
            accept_suggestion(
                buf,
                current_edit.start_col,
                current_edit.start_line,
                table.concat(current_edit.lines, "\n")
            )
        end
        clear_diff_buf()
        current_edit = nil
    end
end

local function reject()
    if current_edit then
        clear_diff_buf() -- Clear any virtual lines showing the suggested edit
        current_edit = nil -- Clear the current edit data
    end
end

local function cancel()
    -- I tried to shutdown the curl job here but it caused a bunch of errors to throw.
    reject()
end

return {
    reject = reject,
    accept = accept,
    suggest_addition = suggest_addition,
    suggest_edit = suggest_edit,
    cancel = cancel,
}
