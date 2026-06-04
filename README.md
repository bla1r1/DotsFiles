# DotsFiles

Quick installer for this Sway/Quickshell setup with fish + fastfetch.

Supported distros:
- Arch Linux
- Debian / Ubuntu-based
- Fedora
- Gentoo
- Void Linux
- openSUSE

## Direct one-liner
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap.sh)
```

## Links
- Repo: https://github.com/bla1r1/DotsFiles
- Bootstrap script: https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap.sh

## Local run
```bash
git clone https://github.com/bla1r1/DotsFiles.git ~/DotsFiles
cd ~/DotsFiles
bash install.sh
```

## Interactive UI run
```bash
git clone https://github.com/bla1r1/DotsFiles.git ~/DotsFiles
cd ~/DotsFiles
bash install-ui.sh
```

## Online run (curl)
```bash
curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap.sh | bash
```

## Online run (wget)
```bash
wget -qO- https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap.sh | bash
```

## Useful options
Pass options after repo URL:

```bash
... | bash -s -- --no-aur
... | bash -s -- --skip-packages
... | bash -s -- --skip-dotfiles
... | bash -s -- --skip-services
```

`bootstrap.sh` clones/updates this repo, then runs `install.sh`.
If needed, you can still pass a custom repo URL:

```bash
curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap.sh | bash -s -- https://github.com/other-user/other-dotfiles.git
```

To run the UI installer after online bootstrap:

```bash
~/.local/src/dotfiles/install-ui.sh
```
