local context = require("carrier.context")
-- Function to get all diagnostics for the current buffer
local function get_current_buffer_diagnostics()
    local buffer_id = 0 -- 0 refers to the current buffer
    -- Fetch all diagnostics for the current buffer
    local diagnostics = vim.diagnostic.get(buffer_id)
    return diagnostics
end

local function get_diagnostic_under_cursor()
    local last_buffer, last_buffer_pos = context.get_last_non_carrier_buffer_and_pos()
    if not last_buffer or not last_buffer_pos then
        return "" -- Handle case where there's no non-carrier buffer found
    end
    local row = last_buffer_pos[1] - 1 -- Use the lnum from last non-carrier buffer
    local diagnostics = vim.diagnostic.get(last_buffer, { lnum = row })
    local diagnostics_text = ""
    local total_length = 0
    local max_length = 1000
    for _, diagnostic in ipairs(diagnostics) do
        local message = diagnostic.message
        local message_length = #message
        if total_length + message_length > max_length then
            message = message:sub(1, max_length - total_length)
            diagnostics_text = diagnostics_text .. message
            break -- Since we've reached the max length, no need to continue
        else
            local separator = total_length > 0 and "\n" or ""
            diagnostics_text = diagnostics_text .. separator .. message
            total_length = total_length + message_length + #separator
        end
    end

    return diagnostics_text
end

return {
    get_current_buffer_diagnostics = get_current_buffer_diagnostics,
    get_diagnostic_under_cursor = get_diagnostic_under_cursor,
}
