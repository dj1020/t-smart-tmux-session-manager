# Introducing Sesh 🎉

I've rewritten this project in Go and called it "sesh". It's more flexible and faster than the original script. I'm no longer maintaining this project. I'll leave it up for historical purposes, but I recommend you check out the new project.

[Check out sesh](https://github.com/joshmedeski/sesh)

# t - the smart tmux session manager

tmux is a powerful tool, but dealing with sessions can be painful. This script makes it easy to create and switch tmux sessions:

<details>
<summary>Documentation</summary>

## Prerequisites

- [tmux](https://github.com/tmux/tmux) (>= 3.2)
- [tpm](https://github.com/tmux-plugins/tpm)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [fzf](https://github.com/junegunn/fzf) (>=0.35.0)

_Note: some users have had issues with fzf integration on tmux 3.2a where upon
spawning fzf it would lock the tmux pane. Upgrading to 3.3a seems to be a viable
workaround_ Check [#104](https://github.com/joshmedeski/t-smart-tmux-session-manager/issues/104)

```sh
brew install tmux zoxide fzf
```

Use the package manager of your OS if you are not on macOS.

## How to install

### 1. Install tpm plugin

Add the following line to your `tmux.conf` file:

```sh
set -g @plugin 'joshmedeski/t-smart-tmux-session-manager'
```

**Note:** tpm recommends you list your plugins and then run tpm at the very bottom of your `tmux.conf`.

Then, run `<prefix>I` to install the plugin.

### 2. Add to path

To use the `t` script from anywhere, select your shell environment and follow the instructions.

**Note:** you'll need to check the path of your tpm plugins. It may be `~/.tmux/plugins` or `~/.config/tmux/plugins` depending on where your `tmux.conf` is located.

<details>
<summary>bash</summary>

Add the following line to `~/.bashrc`

```sh
# ~/.tmux/plugins
export PATH=$HOME/.tmux/plugins/t-smart-tmux-session-manager/bin:$PATH
# ~/.config/tmux/plugins
export PATH=$HOME/.config/tmux/plugins/t-smart-tmux-session-manager/bin:$PATH
```

</details>

<details>
<summary>zsh</summary>

Add the following line to `~/.zprofile`

```sh
# ~/.tmux/plugins
export PATH=$HOME/.tmux/plugins/t-smart-tmux-session-manager/bin:$PATH
# ~/.config/tmux/plugins
export PATH=$HOME/.config/tmux/plugins/t-smart-tmux-session-manager/bin:$PATH
```

</details>

<details>
<summary>fish</summary>

Add the following line to `~/.config/fish/config.fish`

```fish
# ~/.tmux/plugins
fish_add_path $HOME/.tmux/plugins/t-smart-tmux-session-manager/bin
# ~/.config/tmux/plugins
fish_add_path $HOME/.config/tmux/plugins/t-smart-tmux-session-manager/bin
```

</details>

### 3. Recommended tmux settings

I recommend you add these settings to your `tmux.conf` to have a better experience with this plugin.

```sh
bind-key x kill-pane # skip "kill-pane 1? (y/n)" prompt
set -g detach-on-destroy off  # don't exit from tmux when closing a session
```

### 4. Customize Prompt (optional)

If your terminal supports [Nerd Font symbols](https://www.nerdfonts.com/), you can customize your prompt.

```sh
set -g @t-fzf-prompt '  '
```

Or you can replace the prompt with anything you'd like.

## How to use

- **範圍**：tmux session 與真實 Herdr workspace；不包含 window／tab。
- **依賴**：Herdr Mode 需要 Herdr CLI 與 jq；已以 Herdr `0.9.4` 驗證。

| 入口 | `$TMUX` 非空 | `$TMUX` 為空 |
|---|---|---|
| `t` | 鎖定 Tmux Mode，使用 fzf-tmux | Herdr Mode，使用一般 fzf，可用 ctrl-g 切換 tmux |
| `t {name}`／`t {path}` | 先查 zoxide，再查本地目錄 | 先精確比對 workspace 名稱，再查 zoxide、本地目錄 |
| `t -h`／`t --help` | 顯示說明 | 顯示說明 |

- **模式**：非空 `$TMUX` 優先於 `HERDR_ENV`；標題使用 tmux 藍色／Herdr 洋紅色反白。
- **Herdr**：所有指令固定操作 `default`；workspace 先於目錄顯示，保留來源與 ID。
  目錄沿用下方命名設定，精確比對 label；同名多筆取第一個，不改既有工作目錄。
- **進入畫面**：focus 成功後，`HERDR_ENV=1` 不 attach，其餘 attach default。
  公開 CLI focus 會切換同 session 的所有 client；不同 session 可能有相同 workspace ID。
- **冷啟動**：明確未運行才背景啟動，固定等待 0.5 秒後查一次清單；已運行直接查詢。
  固定延遲不保證就緒；失敗報錯退出、不重試、不切 tmux、不停止 server。
  取消選單保留已啟動的 server；CLI 命令本身沒有額外逾時保護。
- **直接輸入**：不開 fzf；Herdr 查無 workspace／目錄就報錯，不以目前目錄建立。
- **已移除**：repository clone、舊來源重載快捷鍵與 `.t` 啟動腳本功能。
  不檢查或執行 `.t`，也不刪除使用者檔案；`-r`／`--repo` 非零退出。

### Key Bindings

| 鍵位 | 行為 |
|---|---|
| `ctrl-g` | 僅非 tmux 的互動選單可來回切換 Herdr／Tmux Mode |
| `tab`／`shift-tab` | 在 fzf 結果中向下／向上移動 |
| `Enter` | 將選項交由當下後端處理 |
| `Esc`／`ctrl-c` | 取消並安靜結束，不執行選取動作 |

- 切換模式會結束並重開 fzf；搜尋文字與游標不保留，畫面可能閃動。
- 選任意目錄請使用 zoxide 清單或 `t {path}`；不再提供選單內臨時目錄搜尋。

## How to customize

### Use Git Root for session name

You may prefer your session names starting from the root of the git repository. This can help with naming conflicts if you have multiple directories with the same name on your machine and make it clear when you have multiple sessions open in the same git repository.

<details>
<summary>bash</summary>

Add the following line to `~/.bashrc`

```sh
export T_SESSION_USE_GIT_ROOT="true"
```

</details>

<details>
<summary>zsh</summary>

Add the following line to `~/.zshrc`

```sh
export T_SESSION_USE_GIT_ROOT="true"
```

</details>

<details>
<summary>fish</summary>

Add the following line to `~/.config/fish/conf.d/t.fish`

```fish
set -Ux T_SESSION_USE_GIT_ROOT true
```

</details>

### Include parent dir in session name

You may prefer your session names having a prefix of the parent directory. This can help with naming conflicts if you have multiple directories with the same name on your machine.

<details>
<summary>bash</summary>

Add the following line to `~/.bashrc`

```sh
export T_SESSION_NAME_INCLUDE_PARENT="true"
```

</details>

<details>
<summary>zsh</summary>

Add the following line to `~/.zshrc`

```sh
export T_SESSION_NAME_INCLUDE_PARENT="true"
```

</details>

<details>
<summary>fish</summary>

Add the following line to `~/.config/fish/conf.d/t.fish`

```fish
set -Ux T_SESSION_NAME_INCLUDE_PARENT true
```

</details>

### Custom fzf-tmux keybinding

By default, the `t` popup is bound to `<prefix>T`. In order to overwrite your own custom key binding, add setting the `@t-bind` varaible to your `tmux.conf`:

```sh
set -g @t-bind "K"
```

You can unbind the default by using `none`.

```sh
set -g @t-bind "none" # unbind default
```

### Change default fzf results

- 此設定只影響 Tmux Mode：server 運行時預設列 session 與 zoxide；
  server 未運行時只列 zoxide。Herdr Mode 不讀 tmux 設定。
- 在 `tmux.conf` 設定 `@t-fzf-default-results`：

```sh
set -g @t-fzf-default-results 'sessions' # show tmux sessions by default
```

```sh
set -g @t-fzf-default-results 'zoxide' # show zoxide results by default
```

### FZF_TMUX_OPTS

If you want to overwrite the fzf-tmux options, you can set the `FZF_TMUX_OPTS` variable in your shell environment.

```bash
# ~/.bashrc or ~/.zshrc
export FZF_TMUX_OPTS="-p 55%,60%"
```

```fish
# ~/.config/fish/config.fish
set -Ux FZF_TMUX_OPTS "-p 55%,60%"
```

Run `man fzf-tmux` to learn more about the available options.

### Custom Border Label

- `T_FZF_BORDER_LABEL` 是兩模式共用的自訂標題前綴；目前模式名稱仍會附加在後。
- 設定方式：

```bash
# ~/.bashrc or ~/.zshrc
export T_FZF_BORDER_LABEL=' Your Custom Label '
```

or if you use fish:

```fish
# ~/.config/fish/config.fish
set -Ux T_FZF_BORDER_LABEL " Your Custom Label "
```

## Background

Interested in learning more about how this script came to be? Check out [Smart tmux sessions with zoxide and fzf](https://www.joshmedeski.com/posts/smart-tmux-sessions-with-zoxide-and-fzf/).
]

## Bonus: macOS keyboard shortcut

My personal workflow uses [macOS Keyboard Shortcuts for tmux](https://www.joshmedeski.com/posts/macos-keyboard-shortcuts-for-tmux/). I have bound the `t` popup to `cmd+j` with the following code:

<details>
<summary>Alacritty</summary>

Add the following line to your `alacritty.yml`

```yml
key_bindings:
  - { key: K, mods: Command, chars: "\x02\x54" } # open t - tmux smart session manager
```

</details>

<details>
<summary>Kitty</summary>

Add the following line to your `kitty.conf`

```sh
map cmd+k send_text all \x02\x54
```

</details>

<details>
<summary>WezTerm</summary>

Add the following line to your `wezterm.lua` inside the **keys** options

```sh
{ key = 'j', mods = 'CMD', action = wezterm.action.SendString '\x02\x54' }, -- open t - tmux smart session manager

```

</details>

**Note:** These bindings are based off the default prefix, `ctrl+b` (which converts to `\x02`). If you changed your prefix, I recommend [watching my video](https://www.joshmedeski.com/posts/macos-keyboard-shortcuts-for-tmux/) which goes into depth how to customize your own keybindings in Alacritty.

</details>
