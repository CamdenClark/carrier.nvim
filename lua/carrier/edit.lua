local openai = require("carrier.openai")
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
    return table.concat(lines, "\n")
end

local function replace_selection(new_text)
    -- Get positions just like in your function
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line, start_col = start_pos[2], start_pos[3]
    local end_line, end_col = end_pos[2], end_pos[3]
    local buffer = vim.api.nvim_get_current_buf()
    -- Split the new text into separate lines
    local new_lines = {}
    for line in new_text:gmatch("([^\n]*)\n?") do
        table.insert(new_lines, line)
    end
    -- Replace the first and last lines to leave the unselected text unchanged
    local old_lines = vim.api.nvim_buf_get_lines(buffer, start_line - 1, end_line, false)
    if start_col > 1 then
        new_lines[1] = old_lines[1]:sub(1, start_col - 1) .. new_lines[1]
    end
    if end_col <= #old_lines[#old_lines] then
        new_lines[#new_lines] = new_lines[#new_lines] .. old_lines[#old_lines]:sub(end_col)
    end
    -- Set the new lines in the buffer
    vim.api.nvim_buf_set_lines(buffer, start_line - 1, end_line, false, new_lines)
end

local add_instruction = [[
Act as an expert software developer.
Respect the user's existing conventions.

You will see a few files that the user has recently edited.
The user's current cursor position will be shown with [cursor].

You should write some code that fits the user's instruction and cursor position.
Only output the updated code snippet.
]]

local edit_instruction = [[
Act as an expert software developer.
Respect the user's existing conventions.

You will see a few files that the user has recently edited.
You will also get a code snippet from one of those files that the user wants to edit.

You should edit that code snippet given the user's instruction. Only ouptut the updated code snippet.
]]

local namespace_name = "carrier_diff"
local namespace = vim.api.nvim_create_namespace(namespace_name)

local function clear_virtual_lines()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
end

local function diff_lines(lines1, lines2)
    local set1 = {}
    local result = {}

    -- Build a table to store the lines from the first set
    for _, line in ipairs(lines1) do
        set1[line] = true
    end

    local i, j = 1, 1
    while i <= #lines1 or j <= #lines2 do
        if lines1[i] == lines2[j] then
            -- Lines are the same, no change
            table.insert(result, { { lines1[i], "normal" } })
            i = i + 1
            j = j + 1
        elseif set1[lines2[j]] then
            -- Line is present in lines1 but at a different position
            table.insert(result, { { lines1[i], "diffRemoved" } })
            i = i + 1
        else
            -- Line is new in lines2
            table.insert(result, { { lines2[j], "diffAdded" } })
            j = j + 1
        end
    end

    return result
end

local function render_edit(buf, row, lines1, lines2)
    local virt_lines = diff_lines(lines1, lines2)

    -- Add each line of text as a virtual line below the cursor
    return vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
        virt_lines = virt_lines,
    })
end

local function suggest_edit()
    local buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local row = cursor_pos[1]

    -- get edit
    local edit_prompt = vim.fn.input("Edit: ")
    local messages = {
        {
            role = "system",
            content = add_instruction
                .. "User's recently edited buffers:\n"
                .. context.get_buffers_content_summary()
                .. "\n",
        },
        {
            role = "user",
            content = "User's edit instruction: " .. edit_prompt,
        },
    }

    local lines = { "" }
    local ext_mark = nil

    local on_delta = function(response)
        if
            response
            and response.choices
            and response.choices[1]
            and response.choices[1].delta
            and response.choices[1].delta.content
            and current_edit
            and not current_edit.job.is_shutdown
        then
            local delta = response.choices[1].delta.content
            for char in delta:gmatch(".") do
                if char == "\n" then
                    lines = vim.list_extend(lines, { "" })
                    clear_virtual_lines()
                    ext_mark = render_edit(buf, row - 1, {}, lines)
                else
                    lines[#lines] = lines[#lines] .. char
                end
            end
        end
    end

    local on_complete = function()
        current_edit = {
            buf = buf,
            lines = lines,
            ext_mark = ext_mark,
        }
    end

    current_edit = {
        buf = buf,
    }

    current_edit.job = openai.stream_chatgpt_completion(config.options, messages, on_delta, on_complete)
end

local function accept_edit()
    if current_edit then
        local buf = current_edit.buf
        local ext_mark = current_edit.ext_mark

        local pos = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, ext_mark, { details = true })
        local row = unpack(pos)
        local lines = current_edit.lines
        vim.api.nvim_buf_set_lines(buf, row, row, false, lines)
        clear_virtual_lines()
    end
end

local function reject_edit()
    if current_edit then
        clear_virtual_lines() -- Clear any virtual lines showing the suggested edit
        current_edit = nil -- Clear the current edit data
    end
end

local function cancel_edit()
    -- I tried to shutdown the curl job here but it caused a bunch of errors to throw.
    reject_edit()
end

return {
    reject_edit = reject_edit,
    accept_edit = accept_edit,
    suggest_edit = suggest_edit,
    cancel_edit = cancel_edit,
}
