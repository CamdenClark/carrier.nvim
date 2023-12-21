local openai = require("carrier.openai")
local context = require("carrier.context")
local diagnostics = require("carrier.diagnostics")
local config = require("carrier.config")

local current_completion_job = nil

local function open_log_with_text(text)
    -- create a new empty buffer
    local buffer = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buffer, "carrier log")
    vim.api.nvim_buf_set_option(buffer, "filetype", "markdown")
    vim.api.nvim_buf_set_option(buffer, "buftype", "nofile") -- Set buffer type to 'nofile'
    vim.api.nvim_buf_set_option(buffer, "swapfile", false) -- Do not create a swapfile
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "hide") -- Hide buffer when abandoned
    local lines = vim.split(text, "\n")

    table.insert(lines, "")
    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, lines)
    return buffer
end

local function get_current_log_buffer()
    local buffers = vim.api.nvim_list_bufs()
    for _, buffer in ipairs(buffers) do
        if vim.api.nvim_buf_is_valid(buffer) then
            local buffer_name = vim.api.nvim_buf_get_name(buffer)
            if buffer_name:match("carrier log") then
                return buffer
            end
        end
    end

    return open_log_with_text("# User")
end

local function open_log()
    local log_buffer = get_current_log_buffer()

    vim.api.nvim_set_current_buf(log_buffer)
    return log_buffer
end

local function open_log_split()
    local log_buffer = get_current_log_buffer()
    vim.cmd("sp | b" .. log_buffer)

    vim.api.nvim_set_current_buf(log_buffer)
    return log_buffer
end

local function open_log_vsplit()
    local log_buffer = get_current_log_buffer()
    vim.cmd("vsp | b" .. log_buffer)

    vim.api.nvim_set_current_buf(log_buffer)
    return log_buffer
end

local function parseMarkdown()
    local messages = {}
    local currentEntry = nil
    local buffer = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    for _, line in ipairs(lines) do
        if line:match("^#%s+(.*)$") then
            local role = line:match("^#%s+(.*)$")
            if currentEntry then
                table.insert(messages, currentEntry)
            end
            currentEntry = {
                role = string.lower(role),
                content = "",
            }
        elseif currentEntry then
            if line ~= "" then
                if currentEntry.content == "" then
                    currentEntry.content = line
                else
                    currentEntry.content = currentEntry.content .. "\n" .. line
                end
            end
        end
    end
    if currentEntry then
        table.insert(messages, currentEntry)
    end

    return messages
end

local main_system = [[Act as an expert software developer.
Always use best practices when coding.
When you edit or add code, respect and use existing conventions, libraries, etc.

Take requests for help with the supplied code.
If the request is ambiguous, ask questions.]]

local function send_message()
    local messages = parseMarkdown()
    local initialMessage = { role = "system", content = main_system }
    local buffersMessage =
        { role = "system", content = "Recently opened buffers:\n" .. context.get_recent_buffers_text() }
    local rootFormMessage = {
        role = "system",
        content = "Code context under user's cursor:\n" .. context.get_largest_direct_descendant_at_cursor(),
    }
    table.insert(messages, 1, initialMessage)
    table.insert(messages, 2, buffersMessage)
    table.insert(messages, 3, rootFormMessage)

    local buffer = get_current_log_buffer()
    local currentLine = vim.api.nvim_buf_line_count(buffer)

    vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, false, { "", "# Assistant", "..." })

    currentLine = vim.api.nvim_buf_line_count(buffer) - 1
    local currentLineContents = ""

    local on_delta = function(response)
        if
            response
            and response.choices
            and response.choices[1]
            and response.choices[1].delta
            and response.choices[1].delta.content
        then
            local delta = response.choices[1].delta.content
            for char in delta:gmatch(".") do
                if char == "\n" then
                    vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, false, { currentLineContents })
                    currentLine = currentLine + 1
                    currentLineContents = ""
                else
                    currentLineContents = currentLineContents .. char
                end
            end
        end
    end

    local on_complete = function()
        vim.api.nvim_buf_set_lines(
            buffer,
            currentLine,
            currentLine + 1,
            false,
            { currentLineContents, "", "# User", "" }
        )
        current_completion_job = nil
        if config.options.on_complete ~= nil then
            config.options.on_complete()
        end
    end

    current_completion_job = openai.stream_chatgpt_completion(config.options, messages, on_delta, on_complete)
end

local function stop_message()
    if current_completion_job and not current_completion_job.is_shutdown then
        current_completion_job:shutdown()
        local buffer = get_current_log_buffer()
        -- get last line
        local currentLine = vim.api.nvim_buf_line_count(buffer) - 1

        vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine + 1, false, { "", "# User", "" })
    end
end

local function log_message(text)
    local buffer = get_current_log_buffer()
    local currentLine = vim.api.nvim_buf_line_count(buffer)
    local lines = vim.split(text, "\n")

    table.insert(lines, "")
    vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, true, lines)
end

-- Add this function to lua/carrier/log.lua
local function quick_message()
    -- Prompt the user for input and store the result in 'user_message'
    local user_message = vim.fn.input("Ask Carrier: ")

    -- Check that the user_message is not empty
    if user_message == nil or user_message:match("^%s*$") then
        return
    end

    log_message(user_message)
    send_message()
end

local function send_diagnostic_help_message()
    -- Grab the first diagnostic under the cursor.
    local all_diagnostics = diagnostics.get_diagnostic_under_cursor()
    local diagnostic = all_diagnostics[1]
    if not diagnostic then
        return
    end
    -- Calculate the range of lines to get around the diagnostic.
    local diagnostic_message = diagnostic and diagnostic.message or "No diagnostics found under cursor."
    local start_line = math.max(diagnostic.lnum - 5, 0) + 1 -- Convert to 1-index and ensure not less than 1.
    local end_line = diagnostic.end_lnum + 5 + 1 -- Add 1 to account for end line, convert to 1-index.
    local total_lines = vim.api.nvim_buf_line_count(0) -- Count total lines in the buffer.
    end_line = math.min(end_line, total_lines) -- Ensure not greater than total number of lines.

    -- Fetch the lines around the diagnostic
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false) -- Use 0-index for the API call.
    local diagnostic_context = table.concat(lines, "\n")

    open_log()
    log_message(
        "Context: \n" .. diagnostic_context .. "\n\nPlease help me fix this diagnostic:\n" .. diagnostic_message
    )
    send_message()
end

return {
    send_message = send_message,
    open_log = open_log,
    open_log_split = open_log_split,
    open_log_vsplit = open_log_vsplit,
    log_message = log_message,
    stop_message = stop_message,
    quick_message = quick_message,
    send_diagnostic_help_message = send_diagnostic_help_message,
}
