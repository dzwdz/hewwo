# hewwo, an irc client
![Screenshot_2023-06-29_18-30-42](https://github.com/dzwdz/hewwo/assets/21179077/4f48fe23-3ac6-4e37-b2d7-de3e9d1daa70)

*hewwo* is a **work-in-progress** IRC client meant to provide a good experience
for first-time IRC users and IRC addicts alike, stemming mostly from my frustration with
the current state of the art. It's designed specifically with [tilde.town](https://tilde.town)
in mind, but it should be usable on other networks too.

## building, etc.
```sh
git submodule update --init # if you cloned the repo without --recurse submodules

make
# no `make install` target yet
# if you're on Linux, just run the binary from wherever
# otherwise, 🤷. sorry
```

## "features"
* hints to guide new users, inspired by seeing a lot of confused IRC first-timers struggling to quit `#tildetown`
* not a TUI -- works with your terminal (native scrollback, search, etc), not despite it
* dotfile aware -- won't mess up your config unless ask, you can delete the default values and it'll still work
* can send and receive messages
