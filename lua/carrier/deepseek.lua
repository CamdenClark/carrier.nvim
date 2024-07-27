local curl = require("plenary.curl")

local function get_headers(options)
    return {
        Authorization = "Bearer " .. options.config.api_key,
        Content_Type = "application/json",
    }
end

local function stream_fim_completion(options, prompt, suffix, on_delta, on_complete)
    return curl.post("https://api.deepseek.com/beta/completions", {
        headers = get_headers(options),
        body = vim.fn.json_encode({
            model = "deepseek-coder",
            prompt = prompt,
            suffix = suffix,
            stream = true,
        }),
        stream = vim.schedule_wrap(function(_, data, _)
            if not data then
                return
            end
            local raw_message = string.gsub(data, "^data: ", "")
            if raw_message == "[DONE]" then
                on_complete()
            elseif string.len(data) > 6 then
                local ok, decoded_data = pcall(vim.fn.json_decode, string.sub(data, 6))
                if
                    ok
                    and decoded_data
                    and decoded_data.choices
                    and decoded_data.choices[1]
                    and decoded_data.choices[1].text
                then
                    on_delta(decoded_data.choices[1].text)
                end
            end
        end),
    })
end

local edit_system_prompt = [[
Act as an expert software developer.
Respect the user's existing conventions.

You will see a few files that the user has recently edited.
You will also get a code snippet from one of those files that the user wants to edit.

You should edit that code snippet given the user's instruction. Only ouptut the updated code snippet.
]]

local function stream_edit_completion(options, context, on_delta, on_complete)
    local messages = {
        {
            role = "system",
            content = edit_system_prompt .. "User's recently edited buffers:\n" .. context.buffer_content .. "\n",
        },
        {
            role = "user",
            content = "Snippet to edit:\n"
                .. context.selection
                .. "\n\n"
                .. "User's edit instruction: "
                .. context.edit_instruction,
        },
        {
            role = "assistant",
            content = "```lua\n",
            prefix = true,
        },
    }
    return curl.post("https://api.deepseek.com/beta/chat/completions", {
        headers = get_headers(options),
        body = vim.fn.json_encode({
            model = "deepseek-coder",
            messages = messages,
            stop = { "```" },
            stream = true,
        }),
        stream = vim.schedule_wrap(function(_, data, _)
            if not data then
                return
            end
            local raw_message = string.gsub(data, "^data: ", "")
            if raw_message == "[DONE]" then
                on_complete()
            elseif string.len(data) > 6 then
                local ok, decoded_data = pcall(vim.fn.json_decode, string.sub(data, 6))
                if
                    ok
                    and decoded_data
                    and decoded_data.choices
                    and decoded_data.choices[1].delta
                    and decoded_data.choices[1].delta.content
                then
                    on_delta(decoded_data.choices[1].delta.content)
                end
            end
        end),
    })
end

return {
    stream_fim_completion = stream_fim_completion,
    stream_edit_completion = stream_edit_completion,
}
