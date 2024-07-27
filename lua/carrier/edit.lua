local openai = require("carrier.openai")
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

-- Get positions just like in your function
local function replace_selection(buffer, start_line, start_col, end_line, end_col, new_text)
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
Only output the updated code snippet. Do NOT output backticks or code block markdown formatting.
]]

local edit_instruction = [[
Act as an expert software developer.
Respect the user's existing conventions.

You will see a few files that the user has recently edited.
You will also get a code snippet from one of those files that the user wants to edit.

You should edit that code snippet given the user's instruction. Only ouptut the updated code snippet.
Do NOT output backticks or code block markdown formatting.
]]

local namespace_name = "carrier_edit"
local namespace = vim.api.nvim_create_namespace(namespace_name)

local function clear_virtual_lines()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
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

local function render_edit(buf, row, lines1, lines2)
    local virt_lines = diff_lines(lines1, lines2)

    -- Add each line of text as a virtual line below the cursor
    return vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
        virt_lines = virt_lines,
    })
end

local function suggest_edit()
    local buf = vim.api.nvim_get_current_buf()

    local start_line, start_col, end_line, end_col, selection = get_selection()

    local selection_lines = vim.split(selection, "\n")

    -- get edit
    local edit_prompt = vim.fn.input("Edit: ")
    local messages = {
        {
            role = "system",
            content = edit_instruction
                .. "User's recently edited buffers:\n"
                .. context.get_buffers_content_summary()
                .. "\n",
        },
        {
            role = "user",
            content = "Snippet to edit:\n" .. selection .. "\n\n" .. "User's edit instruction: " .. edit_prompt,
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
                    ext_mark = render_edit(buf, end_line - 1, selection_lines, lines)
                else
                    lines[#lines] = lines[#lines] .. char
                end
            end
        end
    end

    local on_complete = function()
        clear_virtual_lines()
        ext_mark = render_edit(buf, end_line - 1, selection_lines, lines)
        current_edit = {
            job = current_edit and current_edit.job,
            buf = buf,
            lines = lines,
            ext_mark = ext_mark,
            start_col = start_col,
            start_line = start_line,
            end_col = end_col,
            end_line = end_line,
        }
    end

    current_edit = {
        buf = buf,
        start_col = start_col,
        start_line = start_line,
        end_col = end_col,
        end_line = end_line,
    }

    current_edit.job = openai.stream_chatgpt_completion(config.options, messages, on_delta, on_complete)
end

-- add binary search in lua

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
    local ext_mark = nil

    local on_delta = function(response)
        if
            response
            and response.choices
            and response.choices[1]
            and response.choices[1].text
            and current_edit
            and not current_edit.job.is_shutdown
        then
            local delta = response.choices[1].text
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
        clear_virtual_lines()
        ext_mark = render_edit(buf, row - 1, {}, lines)
        current_edit = {
            buf = buf,
            lines = lines,
            ext_mark = ext_mark,
        }
    end

    current_edit = {
        buf = buf,
    }

    -- Call the modified deepseek.stream_fim_completion function
    current_edit.job = deepseek.stream_fim_completion(config.options, prompt, suffix, on_delta, on_complete)
end

local function accept()
    if current_edit then
        local buf = current_edit.buf
        local ext_mark = current_edit.ext_mark

        if current_edit.start_col then
            replace_selection(
                buf,
                current_edit.start_line,
                current_edit.start_col,
                current_edit.end_line,
                current_edit.end_col,
                table.concat(current_edit.lines, "\n")
            )
        else
            local pos = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, ext_mark, { details = true })
            local row = unpack(pos)
            local lines = current_edit.lines
            vim.api.nvim_buf_set_lines(buf, row, row, false, lines)
        end
        clear_virtual_lines()
        current_edit = nil
    end
end

local function reject()
    if current_edit then
        clear_virtual_lines() -- Clear any virtual lines showing the suggested edit
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
