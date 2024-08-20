local curl = require("plenary.curl")

local function get_headers(options)
    return {
        ["api-key"] = options.config.api_key,
        ["Content-Type"] = "application/json",
    }
end

local function get_api_url(options)
    return string.format(
        "https://%s/openai/deployments/%s/chat/completions?api-version=2024-06-01",
        options.config.endpoint,
        options.config.deployment
    )
end

local fim_system_prompt = [[
You are an AI assistant specialized in code completion tasks. Your role is to complete code snippets intelligently, focusing on the following guidelines:
1. Maintain consistency with the existing code style and conventions.
2. Ensure the completed code is syntactically correct and logically sound.
3. Consider the context provided by the surrounding code.
4. Only return the code snippet that needs to be completed. Don't return any of the surrounding code.
5. Don't include ```, just return the code
Your task is to fill in the missing part of the code, represented by <fim_hole> in the user's prompt.
]]

local function stream_fim_completion(options, prompt, suffix, on_delta, on_complete)
    local messages = {
        { role = "system", content = fim_system_prompt },
        { role = "user", content = prompt .. "<fim_hole>" .. suffix },
    }
    return curl.post(get_api_url(options), {
        headers = get_headers(options),
        body = vim.fn.json_encode({
            model = "gpt-4o",
            messages = messages,
            stream = true,
            stop = "```",
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
                    and decoded_data.choices[1].delta
                    and decoded_data.choices[1].delta.content
                then
                    on_delta(decoded_data.choices[1].delta.content)
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
You should edit that code snippet given the user's instruction. Only output the updated code snippet.
Only return the code snippet that needs to be completed. Don't return any of the surrounding code.
Don't include ```, just return the code
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
    }
    return curl.post(get_api_url(options), {
        headers = get_headers(options),
        body = vim.fn.json_encode({
            model = "gpt-4o",
            messages = messages,
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
