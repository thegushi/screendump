# screendump

GNU screen window titles + scrollback capture with git sync.

Sets your screen window titles automatically based on what you're running,
and lets you dump any window's full scrollback buffer to a file that gets
committed and pushed to a git repo — so you can pull it down anywhere
(VS Code, your Mac, wherever) without any polling daemon or new protocol.

## The problem this solves

My primary work desktop is often a single GNU screen session on a remote
server, connected to multiple machines — channel-surfing between them,
editing files, running Alpine, doing compiles, watching logs, etc.

Sometimes I have a long piece of output (say, `show run` on a router) that I
need to capture for annotation elsewhere.

In a normal SSH session, you can just use your mouse wheel or trackpad to
scroll up and copy/paste. But scrollback within iTerm is useless inside GNU
screen — anything in iTerm's scrollback buffer is polluted by output from
prior screen windows, not necessarily the current one.

GNU screen does have its own keyboard-driven scrollback mode (enter it with
`Ctrl-A [`, then use `B` and `F` to move a screen-length at a time), and
screen has its own paste buffer that works between windows — but unless you
paste your scrollback into a temporary file and then `scp` that file to your
client machine, that paste buffer isn't useful for getting content back to
where you're actually working.

This solves that.

## How it works

`preexec` and `precmd` hooks (via
[bash-preexec](https://github.com/rcaloras/bash-preexec)) fire around every
command. They set the screen window title to the first and last token of the
command line plus the hostname, so your screen window list (`Ctrl-A "`) reads
like a live topology map:

```
 0 bash [horse.gushi.org]
 3 ssh rider [horse.gushi.org]
 7 [root] tail syslog [glendale.gushi.org]
13 vim named.conf [rider.gushi.org]
```

The `screendump` function captures the full scrollback of any window, names
the output file after the window title and a timestamp, and pushes it to a
bare git repo. Your other machines just `git pull`.

## Dependencies

- [GNU screen](https://www.gnu.org/software/screen/)
- [bash-preexec](https://github.com/rcaloras/bash-preexec)
- `git`

## Setup

### 1. Set up the scrollback git repo on your remote host

Create a bare repo to push to, then clone it as your working scrollback
directory:

```bash
git init --bare ~/scrollback.git
git clone ~/scrollback.git ~/scrollback
```

### 2. Install the script

Clone this repo somewhere on the remote host, or just copy `screen-titles.sh`:

```bash
git clone https://github.com/thegushi/screendump.git ~/screendump
```

### 3. Source it from your `.bashrc`

`bash-preexec` must be sourced first:

```bash
[ -f ~/.bash-preexec.sh ] && source ~/.bash-preexec.sh
[ -f ~/screendump/screen-titles.sh ] && source ~/screendump/screen-titles.sh
```

If you don't have `bash-preexec` yet:

```bash
curl https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh \
  -o ~/.bash-preexec.sh
```

### 4. Set up the pull side (Mac / VS Code / wherever)

On your local machine, clone from the remote's bare repo over SSH:

```bash
git clone you@horse:scrollback.git ~/scrollback
```

Then `git pull` whenever you want the latest dumps. Or open the directory in
VS Code — hit the sync button when you need it. Editors like VS Code that
support automatic git refresh can make this even more seamless, pulling new
dumps in the background as long as you have SSH keys set up for the remote.

## Usage

```bash
# Dump the current screen window
screendump

# Dump a specific window by number
screendump 3
```

Output files land in `~/scrollback/` with names like:

```
ssh_rider.gushi.org_horse.gushi.org_-202504131045.txt
tail_syslog_glendale.gushi.org_-202504131312.txt
```

The commit and push happen silently. On the pull side, `git pull` and the
files are there.

## Screenrc tip

You can bind `screendump` to a key in your `.screenrc` so you never have to
type it:

```
bind s stuff "screendump\n"
```

`Ctrl-A s` will then dump the current window's scrollback and push it.
(Overrides the default `Ctrl-A s` xon/xoff binding, which you probably
don't need.)

## Root detection

If your effective UID is 0, a `[root]` prefix is prepended to the window
title automatically. Since this is checked on every `preexec` and `precmd`
call, it works regardless of how you elevated — `su`, `sudo -i`, `ksu`,
whatever — and clears itself as soon as you drop back to your normal user:

```
 0 bash [horse.gushi.org]
 3 [root] bash [horse.gushi.org]
 7 [root] vim named.conf [horse.gushi.org]
13 ssh rider.gushi.org [horse.gushi.org]
```

## SSH hops

Because the title is set by the shell on whichever machine you're actually
typing on, this follows you across SSH hops automatically. If you `ssh` from
`horse` to `rider` and `rider` also has the script installed, your window
title updates to reflect what you're running on `rider`. Hop to a third
machine that also has it, same thing.

If a remote host *doesn't* have the script installed, the title simply stays
as `ssh rider.gushi.org [horse.gushi.org]` — the last thing `preexec` saw before you left. That's
still useful: you can see from the window list that the window is in an SSH
session and where it went, you just won't see what's running there.

## Notes

- The `.title.<n>` dotfiles in `~/scrollback/` track the last-seen title for
  each screen window number. They're committed along with the dumps, which is
  harmless.
- Title sanitization strips spaces, slashes, and brackets and collapses runs
  of underscores, so filenames stay readable and shell-safe.
- The `screendump` command itself is excluded from title updates so you don't
  get a window titled `screendump [host]`.

## License

[ISC](LICENSE) — because of course.
