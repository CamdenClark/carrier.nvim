local openai = require("carrier.openai")
local context = require("carrier.context")
local config = require("carrier.config")

local function open_log_with_text(text)
    -- create a new empty buffer
    local buffer = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buffer, "carrier log")
    vim.api.nvim_buf_set_option(buffer, "filetype", "markdown")
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
        { role = "system", content = "Recently opened buffers: " .. context.get_recent_buffers_text() }
    table.insert(messages, 1, initialMessage)
    table.insert(messages, 2, buffersMessage)

    local buffer = vim.api.nvim_get_current_buf()
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
            if delta == "\n" then
                vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, false, { currentLineContents })
                currentLine = currentLine + 1
                currentLineContents = ""
            elseif delta:match("\n") then
                for line in delta:gmatch("[^\n]+") do
                    vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, false, { currentLineContents .. line })
                    currentLine = currentLine + 1
                    currentLineContents = ""
                end
            elseif delta ~= nil then
                currentLineContents = currentLineContents .. delta
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
        if config.options.on_complete ~= nil then
            config.options.on_complete()
        end
    end

    openai.stream_chatgpt_completion(config.options, messages, on_delta, on_complete)
end

local function log_message(text)
    local buffer = get_current_log_buffer()
    local currentLine = vim.api.nvim_buf_line_count(buffer)
    local lines = vim.split(text, "\n")

    table.insert(lines, "")
    vim.api.nvim_buf_set_lines(buffer, currentLine, currentLine, true, lines)
end

return {
    send_message = send_message,
    open_log = open_log,
    open_log_split = open_log_split,
    open_log_vsplit = open_log_vsplit,
    log_message = log_message,
}
