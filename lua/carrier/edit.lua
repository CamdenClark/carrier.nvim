local openai = require("carrier.openai")
local config = require("carrier.config")
local context = require("carrier.context")

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

local edit_instruction = [[Act as an expert software developer.
Always use best practices when coding.
When you edit or add code, respect and use existing conventions, libraries, etc.
Return an edit of the code given a user's instruction. Only return the edited code, don't use markdown backticks,
and don't provide any commentary.
]]

local function edit_selection()
    local edit_prompt = vim.fn.input("Enter an edit instruction...")
    local selection = get_selection()
    local messages = {
        {
            role = "system",
            content = edit_instruction
                .. "User's recently edited buffers:\n"
                .. context.get_recent_buffers_text()
                .. "\n",
        },
        {
            role = "user",
            content = selection .. "\n\n" .. "" .. "User's edit instruction: " .. edit_prompt,
        },
    }
    local replacement = openai.get_chatgpt_completion(config.options, messages)
    replace_selection(replacement)
end

return {
    edit_selection = edit_selection,
}
