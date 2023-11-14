local log = require("carrier.log")
local openai = require("carrier.openai")
local config = require("carrier.config")
local mock = require("luassert.mock")

describe("open_log", function()
    it("opens a new buffer with log in it", function()
        -- Call the function with a range of lines and a new string
        log.open_log()

        -- Assert that the selected lines were replaced with the expected string
        local expected_lines = { "# User", "" }
        local actual_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        assert.are.same(expected_lines, actual_lines)
    end)
end)

local function completion_delta(delta)
    return {
        id = "chatcmpl-123",
        object = "edit",
        created = 1677652288,
        choices = {
            {
                delta = {
                    content = delta,
                },
                index = 0,
            },
        },
        usage = {
            prompt_tokens = 9,
            completion_tokens = 12,
            total_tokens = 21,
        },
    }
end

local function test_completion(start_content, chat_gpt_output, expected_loading, expected_after)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, start_content)
    mock.new(openai, true)

    openai.stream_chatgpt_completion = function(_, _, on_delta, on_complete)
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        assert.are.same(expected_loading, lines)

        for _, delta in ipairs(chat_gpt_output) do
            on_delta(completion_delta(delta))
        end
        on_complete()
    end

    log.send_message()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    assert.are.same(expected_after, lines)
end

describe("send_message", function()
    it("sends the correct user message to the openai endpoint", function()
        test_completion({ "# User", "Some content", "Second line" }, { "Output" }, {
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "...",
        }, {
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "Output",
            "",
            "# User",
            "",
        })
    end)
    it("multi-turn chats are sent as expected", function()
        test_completion({
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "test",
            "",
            "# User",
            "Second user message",
        }, { "Output" }, {
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "test",
            "",
            "# User",
            "Second user message",
            "",
            "# Assistant",
            "...",
        }, {
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "test",
            "",
            "# User",
            "Second user message",
            "",
            "# Assistant",
            "Output",
            "",
            "# User",
            "",
        })
    end)
    it("multiline assistant messages get handled correctly", function()
        test_completion({ "# User", "Some content", "Second line" }, { "Hello ", "World", "\n", "Foo", " Bar" }, {
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "...",
        }, {
            "# User",
            "Some content",
            "Second line",
            "",
            "# Assistant",
            "Hello World",
            "Foo Bar",
            "",
            "# User",
            "",
        })
    end)
    it("calling a configured on_complete function works", function()
        local called = false

        config.setup({
            on_complete = function()
                called = true
            end,
        })

        vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# User", "Foo" })
        mock.new(openai, true)

        openai.stream_chatgpt_completion = function(_, _, on_delta, on_complete)
            for _, delta in ipairs({ "# Assistant", "Hello world" }) do
                on_delta(completion_delta(delta))
            end
            on_complete()
        end

        log.send_message()

        assert.are.same(true, called)
    end)
end)
