# DotsFiles (Arch Linux)

Quick installer for this Hyprland/Waybar/SwayNC setup on Arch.

## Local run
```bash
git clone <YOUR_REPO_URL> ~/DotsFiles
cd ~/DotsFiles
bash install-arch.sh
```

## Online run (curl)
```bash
curl -fsSL https://raw.githubusercontent.com/<USER>/<REPO>/main/bootstrap-arch.sh | bash -s -- https://github.com/<USER>/<REPO>.git
```

## Online run (wget)
```bash
wget -qO- https://raw.githubusercontent.com/<USER>/<REPO>/main/bootstrap-arch.sh | bash -s -- https://github.com/<USER>/<REPO>.git
```

## Useful options
Pass options after repo URL:

```bash
... | bash -s -- https://github.com/<USER>/<REPO>.git --no-aur
... | bash -s -- https://github.com/<USER>/<REPO>.git --skip-packages
... | bash -s -- https://github.com/<USER>/<REPO>.git --skip-dotfiles
... | bash -s -- https://github.com/<USER>/<REPO>.git --skip-services
```

`bootstrap-arch.sh` clones/updates repo, then runs `install-arch.sh`.
