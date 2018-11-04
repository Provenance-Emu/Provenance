# Contributing Guidelines

This document contains information about contributing to this project.
Please read it before you start participating.

**Topics**

* [Asking Questions](#asking-questions)
* [Reporting Issues](#reporting-issues)
* [Pull Requests](#pull-requests)

## Asking Questions

For questions that are not about specific code or documentation issues,
please ask on [Stack Overflow](https://stackoverflow.com). You can search for existing ZIP Foundation related questions by using the `zipfoundation` tag:
https://stackoverflow.com/questions/tagged/zipfoundation. Please also use this tag when creating new questions.

## Reporting Issues

Prior to opening a new issue, please check that the project issues database doesn't already contain a similar issue.  
If you find a match, add a quick "+1" comment.  

When reporting issues, please include the following:

* The version of Xcode you're using
* The version of macOS, iOS, tvOS or watchOS you're targeting
* If you are experiencing problems on non-Apple platforms, please include information about your environment (Swift version, Linux distribution, etc...)
* For code related problems, please include relevant snippets
* Any other details that would be useful in understanding the issue

## Pull Requests

All contributions must be sent in via GitHub pull request. Before opening a pull request, please make sure that:

* All units test pass
* Code coverage stays at 100%
* Added code paths are compatible with all supported platforms
* Code style does not trigger any swiftlint issues (Make sure you have the current [swiftlint](https://github.com/realm/SwiftLint) version installed)
