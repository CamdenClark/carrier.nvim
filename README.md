# carrier.nvim

carrier.nvim is a Neovim plugin that integrates AI-powered editing suggestions directly into your editor. It supports multiple AI providers and offers enhanced editing capabilities.

It's designed to be turnkey: put in your API key, and you're ready to go. carrier.nvim handles the rest.

## Features

- AI-powered editing suggestions
- Support for multiple AI providers (OpenAI, Claude, Azure, DeepSeek)
- In-place editing suggestions with diff view
- Easy accept/reject mechanism for suggested edits

## Installation

Install carrier.nvim using your preferred package manager. Here's an example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "CamdenClark/carrier.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("carrier").setup({
      -- Your configuration options here
    })
  end,
}
```

## Configuration

carrier.nvim has turnkey configuration for multiple AI providers. Configure carrier.nvim in your Neovim configuration:

```lua
require("carrier").setup({
  provider = "deepseek", -- or "openai", "claude", "azure"
  config = {
    -- Provider-specific configuration
  },
})
```

### OpenAI Configuration

To use OpenAI's models:

```lua
require("carrier").setup({
  provider = "openai",
  config = {
    api_key = vim.env.OPENAI_API_KEY,
    model = "gpt-4", -- or "gpt-3.5-turbo-16k", "gpt-4-32k", etc.
  },
})
```

Make sure to set your `OPENAI_API_KEY` environment variable or provide it directly in the configuration.

### Claude Configuration (Under construction)

For Anthropic's Claude:

```lua
require("carrier").setup({
  provider = "claude",
  config = {
    api_key = vim.env.ANTHROPIC_API_KEY,
  },
})
```

### Azure OpenAI Configuration

To use Azure OpenAI:

```lua
require("carrier").setup({
  provider = "azure",
  config = {
    api_key = vim.env.AZURE_OPENAI_API_KEY,
    endpoint = vim.env.AZURE_OPENAI_ENDPOINT,
    deployment_name = "your-deployment-name",
  },
})
```

### DeepSeek Configuration

For DeepSeek models:

```lua
require("carrier").setup({
  provider = "deepseek",
  config = {
    api_key = vim.env.DEEPSEEK_API_KEY,
  },
})
```

## Usage

carrier.nvim provides several commands for AI-assisted editing:

1. **Suggest Edit**: 
   - Visual mode: Select the text you want to edit, then run `:CarrierSuggestEdit`.
   - You'll be prompted to enter an edit instruction.

2. **Suggest Addition**:
   - Place your cursor where you want to add text, then run `:CarrierSuggestAddition`.

3. **Accept Suggestion**:
   - After reviewing the suggested edit in the diff view, run `:CarrierAccept` to apply the changes.

4. **Reject Suggestion**:
   - If you don't want to apply the suggested changes, run `:CarrierReject`.

5. **Cancel Operation**:
   - To cancel the current suggestion process, use `:CarrierCancel`.

## Key Mappings

You can set up key mappings for these commands in your Neovim configuration. For example:

```lua
vim.api.nvim_set_keymap('v', '<leader>ce', ':CarrierSuggestEdit<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>ca', ':CarrierSuggestAddition<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>cy', ':CarrierAccept<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>cn', ':CarrierReject<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>cc', ':CarrierCancel<CR>', { noremap = true, silent = true })
```

## How It Works

1. When you request an edit or addition, carrier.nvim sends your selected text (for edits) or surrounding context (for additions) to the configured AI provider.
2. The AI generates a suggestion, which is displayed in a new buffer as a diff view.
3. You can review the changes in the diff view. Lines in green are additions, and lines in red are removals.
4. Accept the changes to apply them to your original buffer, or reject them to close the diff view without making changes.

## Development

### Running Tests

Running tests requires [plenary.nvim][plenary] to be checked out in the parent directory of _this_ repository. You can then run:

```bash
just test
```

or, more verbose:

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"
```

To run a single test file:

```bash
just test chat_spec.lua
```

```bash
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/path_to_file.lua {minimal_init = 'tests/minimal.vim'}"
```

Read the [nvim-lua-guide][nvim-lua-guide] for more information on developing Neovim plugins.

[plenary]: https://github.com/nvim-lua/plenary.nvim
[nvim-lua-guide]: https://github.com/nanotee/nvim-lua-guide

## Contributing

Contributions to carrier.nvim are welcome! Please feel free to submit pull requests or create issues on the GitHub repository.

## License

MIT

