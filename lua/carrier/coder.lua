local HEAD = "<<<<<<< SEARCH"
local DIVIDER = "======="
local UPDATED = ">>>>>>> REPLACE"
local split_re = "(.-)\n" .. HEAD .. "\n(.-)\n" .. DIVIDER .. "\n(.-)\n" .. UPDATED

local function find_update_block(content)
    local above, search, replace = string.match(content, split_re)
    local filename = above:match("```.*\n(.-)$")

    return { filename, search, replace }
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
-- print(find_update_block(edit))
