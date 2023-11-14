local HEAD = "<<<<<<< SEARCH"
local DIVIDER = "======="
local UPDATED = ">>>>>>> REPLACE"
local split_re = "(.-)\n" .. HEAD .. "\n(.-)\n" .. DIVIDER .. "\n(.-)\n" .. UPDATED

local function find_update_block(content)
    local above, search, replace = string.match(content, split_re)
    local filename = above:match("```.*\n(.-)$")

    return { filename, search, replace }
end

local function replace_in_buffer(bufnr, update_block)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local _, search, replace = unpack(update_block)

    local contents = table.concat(lines, "\n")

    contents = contents:gsub(search, replace)

    -- Split the contents back into lines
    local new_lines = {}
    for line in contents:gmatch("([^\n]*)\n?") do
        table.insert(new_lines, line)
    end

    -- Set the lines in the buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

local function replace_in_buffer_by_filename(update_block)
    local bufnr = vim.fn.bufnr(update_block[1])
    if bufnr == -1 then
        return
    end
    replace_in_buffer(bufnr, update_block)
end

local function update_buffers_with_message(message)
    local update_block = find_update_block(message)
    replace_in_buffer_by_filename(update_block)
end

local edit = [[
Heres the change:

```text
foo.txt
<<<<<<< SEARCH
Two
Foo
=======
Tooooo
>>>>>>> REPLACE
```

Hope you like it!
]]

return { update_buffers_with_message = update_buffers_with_message }
