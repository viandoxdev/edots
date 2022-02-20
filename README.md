# edots - my gentoo dots files

![screenshot](pics/1.png)
![screenshot](pics/2.png)
![screenshot](pics/3.png)

## Uses

 - Sway
 - Ranger
 - Kitty
 - zsh
 - jetbrains mono
 - wofi
 - more (not everyting is documented yet)

## How to use

Too lazy to explain the whole thing in details so:
 - Clone the repo in `~/dots`
 
 > can't be anywhere else for now

 - Either simlink the different configs in [config](config/) to where they should be to be recognised, or if its possible use some kind of `include` syntax to have them read.

# Notes

The scripts in these dots files rely quite a bit on `/tmp` being a tmpfs / ramfs. While nothing will break if it is not, it being one will make the scripts run faster, and lessen drive usages. This is the case by default on systemd, but not on openrc ([link](https://wiki.gentoo.org/wiki/Tmpfs)).
