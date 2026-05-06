# DotsFiles (Arch Linux)

Quick installer for this swayfx/Waybar/SwayNC setup on Arch (including fish + fastfetch).

## Direct one-liner
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap-arch.sh)
```

## Links
- Repo: https://github.com/bla1r1/DotsFiles
- Bootstrap script: https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap-arch.sh

## Local run
```bash
git clone https://github.com/bla1r1/DotsFiles.git ~/DotsFiles
cd ~/DotsFiles
bash install-arch.sh
```

## Interactive UI run
```bash
git clone https://github.com/bla1r1/DotsFiles.git ~/DotsFiles
cd ~/DotsFiles
bash install-arch-ui.sh
```

## Online run (curl)
```bash
curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap-arch.sh | bash
```

## Online run (wget)
```bash
wget -qO- https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap-arch.sh | bash
```

## Useful options
Pass options after repo URL:

```bash
... | bash -s -- --no-aur
... | bash -s -- --skip-packages
... | bash -s -- --skip-dotfiles
... | bash -s -- --skip-services
```

`bootstrap-arch.sh` clones/updates this repo, then runs `install-arch.sh`.
If needed, you can still pass a custom repo URL:

```bash
curl -fsSL https://raw.githubusercontent.com/bla1r1/DotsFiles/main/bootstrap-arch.sh | bash -s -- https://github.com/other-user/other-dotfiles.git
```

To run the UI installer after online bootstrap:

```bash
~/.local/src/dotfiles/install-arch-ui.sh
```
