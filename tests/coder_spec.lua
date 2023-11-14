local coder = require("carrier.coder")
local openai = require("carrier.openai")
local config = require("carrier.config")
local mock = require("luassert.mock")

describe("update_buffers_with_message", function()
    it("edit a real buffer", function()
        -- Add some text to the foo.txt buffer
        vim.api.nvim_command("edit foo.txt")
        vim.api.nvim_buf_set_lines(1, 0, -1, false, { "Two" })

        local edit = [[
Heres the change:

```text
foo.txt
<<<<<<< SEARCH
Two
=======
Too
>>>>>>> REPLACE
```

Hope you like it!
]]

        coder.update_buffers_with_message(edit)
        local lines = vim.api.nvim_buf_get_lines(1, 0, -1, false)

        assert.are.same(true, vim.tbl_contains(lines, "Too"))
    end)
end)

describe("update buffers with message, multiple edits", function()
    it("multiple edits", function()
        -- Add some text to the foo.txt buffer
        vim.api.nvim_command("edit bar.txt")
        local bufnr = vim.fn.bufnr("bar.txt")

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "A", "Two" })

        local edit = [[
Heres the change:

```text
bar.txt
<<<<<<< SEARCH
Two
=======
Too
>>>>>>> REPLACE
```

```text
bar.txt
<<<<<<< SEARCH
A
=======
Bar
>>>>>>> REPLACE
```

Hope you like it!
]]

        coder.update_buffers_with_message(edit)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for _, line in ipairs(lines) do
            print(line)
        end

        assert.are.same("Bar\nToo\n", table.concat(lines, "\n"))
    end)
end)
