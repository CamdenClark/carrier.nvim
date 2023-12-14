# carrier.nvim

carrier is an AI pair programmer that lives in your editor.

It uses OpenAI's GPT models to generate code based on your

## Installation

1. Put your `OPENAI_API_KEY` as an environment variable

```bash
export OPENAI_API_KEY=""
```

2. Have curl installed on your machine

3. Install `plenary.nvim` and `carrier` using your package manager:

For example, using plug

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'CamdenClark/carrier.nvim'
```

## Usage

`:CarrierOpen` functions open a new chat window. Split opens in a horizontal split,
while VSplit opens in a vertical split. They optionally take a template.

```vim
:CarrierOpen
:CarrierOpenSplit
:CarrierOpenVSplit

" open a chat buffer with the current text selected in visual mode
:CarrierOpen visual
```

`:CarrierStart` functions open a new chat window and automatically send the message to the
assistant. You need to provide a template or the first message sent will be blank.

```vim
" starts a chat session with the current text selected in visual mode
:CarrierStart visual
:CarrierStartSplit visual
:CarrierStartVSplit visual
```

To send a message:

```vim
:CarrierSendMessage
```

The response from the Assistant will be streamed back to the same buffer.

## Configuration

### Templates

You can configure custom sources and templates for your ChatGPT prompts.

```lua
require('carrier.config').setup({
  sources = {
    my_source = function () return "world" end
  },
  templates = {
    my_template = {
      template_fn = function(sources) return "# User\nHello, " .. sources.my_source() end
      -- :CarrierOpen my_template
      -- Output:
      -- # User
      -- Hello, world
    }
  }
})
```

Sources are intended to be helpers to get common pieces of data that you'd be
interested in to build your prompts to ChatGPT. Some sources are pre-created,
including `visual`, which provides the text that's visually selected.

Templates are how you construct prompts that will be sent to ChatGPT.

#### Visual selection

Carrier supports adding something you've selected in visual mode to the contents
of a prompt:

```lua
require('carrier.config').setup({
  templates = {
    unit_test = {
      template_fn = function(sources)
          return "# User\n"
            .. "Write a unit test for the following code:\n"
            .. sources.visual()
      end
      -- :CarrierStart unit_test
      -- Output:
      -- # User
      -- Write a unit test for the following
      -- <Your visual selection>
    }
  }
})
```

#### Buffer selection

Carrier supports adding the contents of your current buffer to a prompt:

```lua
require('carrier.config').setup({
  templates = {
    unit_test_buffer = {
      template_fn = function(sources)
          return "# User\n"
            .. "Write unit tests for the code in the following file:\n"
            .. sources.buffer()
      end
      -- :CarrierStart unit_test_buffer
      -- Output:
      -- # User
      -- Write a unit test for the following
      -- <Your previous buffer's contents>
    }
  }
})
```

### Alternative models: gpt-3.5-turbo-16k / gpt-4 / gpt-4-32k

If you want to use Carrier with a different model in OpenAI, call setup with the model:

```lua
require('carrier.config').setup({
  -- ...
  model = "gpt-4"
})
```

To change on the fly, call `:CarrierSwitchModel gpt-4`

### Alternative endpoints (Azure OpenAI)

Carrier supports configuring the URL and headers with a different endpoint that shares API compatibility (IE: Azure OpenAI)
with OpenAI, here's a reference implementation:

```lua
require('carrier.config').setup({
  -- should be like "$AZURE_OPENAI_ENDPOINT/openai/deployments/gpt-35-turbo/chat/completions?api-version=2023-07-01-preview"
  url = vim.env.AZURE_OPENAI_GPT4_URL,
  headers = { 
    Api_Key = vim.env.AZURE_OPENAI_GPT4_KEY,
    Content_Type = "application/json"
  }
})
```

where you put the values for `AZURE_OPENAI_GPT4_URL` and `AZURE_OPENAI_GPT4_KEY` in the environment.

If you want to be able to switch URLs based on model, you should make some lua functions in your
init.lua that are bound to re-call setup with the updated URL and API key.

### Callback when message finished

Carrier supports configuring a callback function that is called when a response from the assistant finishes streaming.

```lua
require('carrier.config').setup({
  on_complete = function() print("foo") end
})
```

## Development

### Run tests

Running tests requires [plenary.nvim][plenary] to be checked out in the parent directory of _this_ repository.
You can then run:

```bash
just test
```

or, more verbose:

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"
```

Or if you want to run a single test file:

```bash
just test chat_spec.lua
```

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/path_to_file.lua {minimal_init = 'tests/minimal.vim'}"
```

Read the [nvim-lua-guide][nvim-lua-guide] for more information on developing neovim plugins.

[nvim-lua-guide]: https://github.com/nanotee/nvim-lua-guide
[plenary]: https://github.com/nvim-lua/plenary.nvim
