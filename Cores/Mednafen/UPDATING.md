#  Updating Mednafen

Mednafen isn't on any public git (that I could find), thus we can't use it as a submodule, meaning that updating it is a bit of work, first download the version you want from [https://mednafen.github.io/releases/], and put it inside `Classes` here, replacing the current `mednafen`.

After this is done, we need to do some patching to get it to build, there's no documented process for doing this, but this commit is how it was done from 1.21.3 -> 1.24.3 `445e1af7100f92c294b632e71760cd132cc32c5f`, so if you're lucky you can just re-apply that one.

There's probably going to be files added/removed from mednafen as well, so you'll need to go through our targets and add/remove files as needed.
