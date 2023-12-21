# carrier.nvim

carrier is an AI pair programmer that lives in your editor.

It uses OpenAI's GPT models to generate code based on your

## Installation

1. Put your `OPENAI_API_KEY` as an environment variable

```bash
export OPENAI_API_KEY=""
```

2. Have curl installed on your machine

3. Install `plenary.nvim` and `carrier.nvim` using your package manager:

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
```

To send a message in the carrier log buffer:

```vim
:CarrierSendMessage
```

The response from the Assistant will be streamed back to the same buffer.

## Configuration

### Alternative models: gpt-3.5-turbo-16k / gpt-4 / gpt-4-32k

If you want to use Carrier with a different model in OpenAI, call setup with the model:

```lua
require('carrier').setup({
  -- ...
  model = "gpt-4"
})
```

To change on the fly, call `:CarrierSwitchModel gpt-4`

### Alternative endpoints (Azure OpenAI)

Carrier supports configuring the URL and headers with a different endpoint that shares API compatibility (IE: Azure OpenAI)
with OpenAI, here's a reference implementation:

```lua
require('carrier').setup({
  -- should be like "$AZURE_OPENAI_ENDPOINT/openai/deployments/$AZURE_OPENAI_DEPLOYMENT_NAME/chat/completions?api-version=2023-07-01-preview"
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
require('carrier').setup({
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
