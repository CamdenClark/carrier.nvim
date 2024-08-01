local curl = require("plenary.curl")

local function get_headers(options)
    return {
        ["x-api-key"] = options.config.api_key,
        ["content-type"] = "application/json",
        ["anthropic-version"] = "2023-06-01",
    }
end

local function debug_api_call(api_key, prompt)
    local headers = {
        ["x-api-key"] = api_key,
        ["Content-Type"] = "application/json",
        ["anthropic-version"] = "2023-06-01",
    }

    local body = vim.fn.json_encode({
        model = "claude-3-5-sonnet-20240620",
        messages = {
            { role = "user", content = prompt },
        },
        max_tokens = 1000,
        system = "foo",
        stream = true,
    })

    print("Making API call with the following details:")
    print("Headers:", vim.inspect(headers))
    print("Body:", body)

    local response = curl.post("https://api.anthropic.com/v1/messages", {
        headers = headers,
        body = body,
        --      stream = vim.schedule_wrap(function(_, data, _)
        --         print(data)
        --    end),
    })
    print("\nAPI Response:")
    print("Status:", response.status)
    print("Headers:", vim.inspect(response.headers))
    print("Body:", response.body)

    if response.status ~= 200 then
        print("Error: API request failed")
    else
        local ok, decoded = pcall(vim.fn.json_decode, response.body)
        if ok then
            print("\nDecoded response:")
            print(vim.inspect(decoded))
        else
            print("Error: Failed to decode API response")
        end
    end
end
-- debug_api_call(require("carrier.config").options.config.api_key, "prompt")

local function stream_fim_completion(options, prompt, suffix, on_delta, on_complete)
    local messages = {
        {
            role = "user",
            content = prompt .. "[[fim_middle]]" .. suffix,
        },
        {
            role = "assistant",
            content = "```\n",
        },
    }

    local function parse_sse_event(data)
        print(data)

        local event, content = data:match("event: (.-)%s*data: (.+)")
        if event and content then
            local ok, decoded = pcall(vim.fn.json_decode, content)
            if ok then
                return event, decoded
            end
        end
        return nil, nil
    end

    return curl.post("https://api.anthropic.com/v1/messages", {
        headers = get_headers(options),
        body = vim.fn.json_encode({
            model = "claude-3-5-sonnet-20240620",
            messages = messages,
            max_tokens = 1000,
            system = "You are an AI assistant performing a fill-in-the-middle task. Complete the code between [[fim_middle]] markers.",
            stream = true,
        }),
        stream = vim.schedule_wrap(function(_, data, _)
            print(data)
            if not data then
                return
            end

            local event, decoded_data = parse_sse_event(data)
            if not event or not decoded_data then
                return
            end

            if event == "message_start" then
                -- Initialization, you might want to do something here
            elseif event == "content_block_start" then
                -- A new content block is starting
            elseif event == "content_block_delta" then
                if decoded_data.delta and decoded_data.delta.type == "text_delta" then
                    on_delta(decoded_data.delta.text)
                end
            elseif event == "content_block_stop" then
                -- A content block has finished
            elseif event == "message_delta" then
                -- Check for completion
                if decoded_data.delta and decoded_data.delta.stop_reason then
                    on_complete()
                end
            elseif event == "message_stop" then
                -- The entire message is complete
                on_complete()
            elseif event == "ping" then
                -- Ping event, typically used to keep the connection alive
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
]]

local function stream_edit_completion(options, context, on_delta, on_complete)
    local messages = {
        {
            role = "user",
            content = "User's recently edited buffers:\n",
        },
        {
            role = "assistant",
            content = "```\n",
        },
    }

    local function parse_sse_event(data)
        local event, content = data:match("event: (.-)%s*data: (.+)")
        if event and content then
            local ok, decoded = pcall(vim.fn.json_decode, content)
            if ok then
                return event, decoded
            end
        end
        return nil, nil
    end

    return curl.post("https://api.anthropic.com/v1/messages", {
        headers = get_headers(options),
        body = vim.fn.json_encode({
            model = "claude-3-5-sonnet-20240620",
            messages = messages,
            max_tokens = 1000,
            system = edit_system_prompt,
            stream = true,
        }),
        stream = vim.schedule_wrap(function(_, data, _)
            if not data then
                return
            end

            local event, decoded_data = parse_sse_event(data)
            print(event)
            if not event or not decoded_data then
                return
            end

            if event == "message_start" then
                -- Initialization, you might want to do something here
            elseif event == "content_block_start" then
                -- A new content block is starting
            elseif event == "content_block_delta" then
                if decoded_data.delta and decoded_data.delta.type == "text_delta" then
                    on_delta(decoded_data.delta.text)
                end
            elseif event == "content_block_stop" then
                -- A content block has finished
            elseif event == "message_delta" then
                -- Check for completion
                if decoded_data.delta and decoded_data.delta.stop_reason then
                    on_complete()
                end
            elseif event == "message_stop" then
                -- The entire message is complete
                on_complete()
            elseif event == "ping" then
                -- Ping event, typically used to keep the connection alive
            end
        end),
    })
end

return {
    stream_edit_completion = stream_edit_completion,
    stream_fim_completion = stream_fim_completion,
}
