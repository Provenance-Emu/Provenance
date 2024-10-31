# Contributing to UnrarKit

First of all, if you're reading this, thanks! I love getting feedback from other developers who use this library and welcome any and all feedback. Issues and Pull requests are welcome, with a few guidelines, laid out below.

# Issues

I need the following, at a minimum:

1. The steps to reproduce your issue, detailed enough for me to follow along and see what you're seeing (bonus points for giving me a sample archive that demonstrates the issue)
2. What you expect to happen
3. What actually happened

If what you're reporting is a crash, a crash report is key (or a stack trace, if you don't have a full crash report).

Beyond that, the **quickest way** to get me to address what you're asking for is to provide a unit test (or tests) to demonstrate what you'd like to see (they should probably fail). I have a pretty complete set of tests already in the library that you can use as an example if you'd like.

# Pull Requests

Pull Requests are always greatly appreciated. The general rule of thumb for how quickly something will make it into a future release is the inverse of how much work I'll need to do on it. Creating a PR instead of an issue report takes a huge burden off of me. If you do create a PR, I'll require these things before I merge it:

1. Style needs to mesh with the rest of the repo. I'd love to have some style enforcement checks at some point, but don't yet. Do your best according to what you see in the rest of the source and I'll point out anything you missed. No big deal
2. If you're fixing a bug, I need to see a unit test that reproduces the issue(s) by failing if I comment out your fix. I try to maintain code coverage that's as complete as possible, so more unit tests are always welcome
3. Don't touch the `Libraries/unrar` directory. This is the UnRAR source code, downloaded from [the RARLAB site](https://www.rarlab.com/rar_add.htm), and updated occasionally. You can usually look at the revision history of that folder to see what version it's currently on. This library does cause some compiler warnings, but I ignore them in Xcode and CocoaPods, relying on unit tests to tell me if anything is truly broken, since I don't maintain patches - I expect to be able to drop in newer versions as needed
4. Be patient with the process - I maintain a high attention to detail, and will take however much time is necessary to get the change to where I'd like it. If you'd rather have a more brief back-and-forth, I can always pull into a separate branch to make the changes myself before merging, but enjoy the interaction of collaborating on PRs whenever possible