local curl = require("plenary.curl")

local function stream_chatgpt_completion(options, messages, on_delta, on_complete)
    curl.post(options.url, {
        headers = options.headers,
        body = vim.fn.json_encode({
            model = options.model,
            temperature = options.temperature,
            messages = messages,
            stream = true,
        }),
        stream = vim.schedule_wrap(function(_, data, _)
            local raw_message = string.gsub(data, "^data: ", "")
            if raw_message == "[DONE]" then
                on_complete()
            elseif string.len(data) > 6 then
                on_delta(vim.fn.json_decode(string.sub(data, 6)))
            end
        end),
    })
end

local function get_chatgpt_completion(options, messages)
    local res = curl.post(options.url, {
        headers = options.headers,
        body = vim.fn.json_encode({
            model = options.model,
            temperature = options.temperature,
            messages = messages,
        }),
    })

    res = vim.fn.json_decode(res.body)
    if res and res.choices and res.choices[1] and res.choices[1].message and res.choices[1].message.content then
        return res.choices[1].message.content
    end
    return ""
end

return {
    get_chatgpt_completion = get_chatgpt_completion,
    stream_chatgpt_completion = stream_chatgpt_completion,
}
