local curl = require("plenary.curl")

local function stream_fim_completion(options, prompt, suffix, on_delta, on_complete)
    print(options.headers.Authorization)
    print(options.model)
    return curl.post("https://api.deepseek.com/beta/completions", {
        headers = options.headers,
        body = vim.fn.json_encode({
            model = options.model,
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
                if ok then
                    on_delta(decoded_data)
                end
            end
        end),
    })
end

local function stream_chat_completion(options, messages, on_delta, on_complete)
    return curl.post(options.url, {
        headers = options.headers,
        body = vim.fn.json_encode({
            model = "deepseek-coder",
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
                if ok then
                    on_delta(decoded_data)
                end
            end
        end),
    })
end

return {
    stream_fim_completion = stream_fim_completion,
}
