local log = require("carrier.log")
-- Function to get all diagnostics for the current buffer
local function get_current_buffer_diagnostics()
    local buffer_id = 0 -- 0 refers to the current buffer
    -- Fetch all diagnostics for the current buffer
    local diagnostics = vim.diagnostic.get(buffer_id)
    return diagnostics
end

local function get_diagnostic_under_cursor()
    local pos = vim.api.nvim_win_get_cursor(0) -- Get the current cursor position
    local row = pos[1] - 1 -- Adjust row for 0-indexing
    local col = pos[2] -- Column is already 0-indexed
    -- Fetch diagnostics for the current buffer and position
    local diagnostics = vim.diagnostic.get(0, { lnum = row, col = col })
    return diagnostics
end

-- Function to grab the diagnostic message under the cursor,
-- add it to the current `carrier log` buffer, and call send_message.
local function send_diagnostic_help_message()
    -- Grab the first diagnostic under the cursor.
    local diagnostics = get_diagnostic_under_cursor()
    local diagnostic = diagnostics[1]
    if not diagnostic then
        return
    end -- Calculate the range of lines to get around the diagnostic.
    local diagnostic_message = diagnostic and diagnostic.message or "No diagnostics found under cursor."
    local start_line = math.max(diagnostic.lnum - 5, 0) + 1 -- Convert to 1-index and ensure not less than 1.
    local end_line = diagnostic.end_lnum + 5 + 1 -- Add 1 to account for end line, convert to 1-index.
    local total_lines = vim.api.nvim_buf_line_count(0) -- Count total lines in the buffer.
    end_line = math.min(end_line, total_lines) -- Ensure not greater than total number of lines.

    -- Fetch the lines around the diagnostic
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false) -- Use 0-index for the API call.
    local context = table.concat(lines, "\n")

    log.open_log()
    -- Add it to the carrier log buffer.
    log.log_message("Context: \n" .. context .. "Please help me fix this diagnostic: " .. diagnostic_message)
    -- Call send_message from log.lua.
    log.send_message()
end

return {
    get_current_buffer_diagnostics = get_current_buffer_diagnostics,
    send_diagnostic_help_message = send_diagnostic_help_message,
}
