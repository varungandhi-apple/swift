# How to set up an edit-build-test-debug loop

This page describes how to get a working Swift development environment,
for people interested in contributing to the Swift project.
If you are only interested in building the toolchain as a one-off,
there are a couple of differences:
1. You can ignore the parts related to Sccache.
2. You can stop reading after [Building the project for the first time](#building-the-project-for-the-first-time).

## Table of Contents

- [System Requirements](#system-requirements)
- [Cloning the project](#cloning-the-project)
- [Installing dependencies](#installing-dependencies)
  - [macOS](#macOS)
  - [Ubuntu Linux](#ubuntu-linux)
- [Building the project for the first time](#building-the-project-for-the-first-time)
  - [Spot check dependencies](#spot-check-dependencies)
  - [Understanding the pieces](#understanding-the-pieces)
  - [The actual build](#the-actual-build)
- [Editing code](#editing-code)
- [Running tests](#running-tests)
- [Debugging issues](#debugging-issues)
- [Next steps](#next-steps)

## System Requirements

1. Operating system:
   The supported operating systems for developing the Swift toolchain are:
   macOS, Ubuntu Linux LTS, and the latest Ubuntu Linux release.
   (Note that Swift itself also runs on Windows, but at the moment,
   it is not supported as a host development operating system.)
2. Python 2:
   Make sure you use Python 2.x. Python 3.x is not supported at the moment.
3. Disk space:
   Make sure that you have enough available disk space before starting.
   The source repositories together require around 3.5 GB.
   Build artifacts, depending on the build settings, take anywhere between
   20 GB to 70 GB.
4. Time:
   Depending on your machine and build settings,
   a from-scratch build can take a few minutes to several hours,
   so you might want to grab a beverage while you follow the instructions.
   Incremental builds are much faster.

## Cloning the project

1. Create a directory for the whole project:
   ```
   mkdir swift-project
   cd swift-project
   ```
2. Clone the sources:
   - Via SSH (recommended):
     If you plan on regularly making direct commits,
     cloning over SSH provides a better experience.
     After you've [uploaded your SSH keys to GitHub][]:
     ```
     git clone git@github.com:apple/swift.git
     cd swift
     ./utils/update-checkout --clone-with-ssh
     ```
   - Via HTTPS:
     If you want to check out the sources as read-only,
     or are not familiar with setting up SSH,
     you can use HTTPS instead:
     ```
     git clone https://github.com/apple/swift.git
     cd swift
     ./utils/update-checkout --clone
     ```
3. Double-check that `swift`'s sibling directories are present.
   ```
   ls ..
   ```
   This should list directories like `llvm-project`, `swiftpm` and so on.

**IMPORTANT:**
The rest of this guide assumes that the absolute path to your working directory
is something like `/path/to/swift-project/swift`.
Double-check that running `pwd` prints a path ending with `swift`, not `swift-project`!

[uploaded your SSH keys to GitHub]: https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/

### Troubleshooting tips

- If `update-checkout` failed, double-check that the absolute path to
  your working directory does not have non-ASCII characters.
- Before running `update-checkout`, double-check that `swift` is the only
  repository inside the `swift-project` directory.
  Otherwise, `update-checkout` may not clone the necessary dependencies.

## Installing dependencies

### macOS

1. Install [Xcode 11.4][] or newer:
   The required version of Xcode changes frequently and is often a beta release.
   Check this document or the host information on <https://ci.swift.org> for the
   current required version.
2. Install [CMake][], [Ninja][] and [Sccache][]:
   - Via [Homebrew][] (recommended):
     ```
     brew install cmake ninja sccache
     ```
   - Via [Homebrew Bundle][]:
     ```
     brew bundle
     ```

[Xcode 11.4]: https://developer.apple.com/xcode/resources/
[CMake]: https://cmake.org
[Ninja]: https://ninja-build.org
[Homebrew]: https://brew.sh/
[Homebrew Bundle]: https://github.com/Homebrew/homebrew-bundle

### Ubuntu Linux

1. For Ubuntu 16.04 LTS and 18.04 LTS, run the following:

   ```
   sudo apt-get install    \
     clang                 \
     cmake                 \
     git                   \
     icu-devtools          \
     libcurl4-openssl-dev  \
     libedit-dev           \
     libicu-dev            \
     libncurses5-dev       \
     libpython-dev         \
     libsqlite3-dev        \
     libxml2-dev           \
     ninja-build           \
     pkg-config            \
     python                \
     python-six            \
     rsync                 \
     swig                  \
     systemtap-sdt-dev     \
     tzdata                \
     uuid-dev
   sudo snap install sccache --candidate --classic
   ```

   For Ubuntu 20.04 LTS, you can run the same command
   but with `libpython2-dev` instead of `libpython-dev`.

   For Ubuntu 14.04 LTS, follow the instructions in [docs/Ubuntu14.md](../Ubuntu14.md).
   You can install `snapd` and Sccache following the instructions
   on [snapcraft.io](https://snapcraft.io/install/sccache/ubuntu).

## Building the project for the first time

### Spot check dependencies

* Run `cmake --version`: This should be 3.16.5 or higher.
* Run `ninja --version`: It doesn't matter what the output is, but this command should succeed.
* Run `sccache --version`: It doesn't matter what the output is, but this command should succeed.
* Run `python --version`: This should be 2.x, not 3.x.

### Understanding the pieces

At this point, it is worthwhile to pause for a moment
to understand what the different tools do:

1. Ninja is a low-level build system that can be used to build the project,
   as an alternative to Xcode's build system.
   Ninja is somewhat faster, especially for incremental builds,
   and supports more build environments.
2. CMake is a cross-platform build system for C and C++.
   It forms the core infrastructure used to configure builds of
   Swift and its companion projects.
3. Sccache is a caching tool:
   If you ever delete your build directory
   and rebuild from scratch (i.e. do a "clean build"), Sccache
   can accelerate the new build significantly.
4. `utils/update-checkout` is a script to help you work with all the individual
   git repositories together, instead of manually cloning/updating each one.
5. `utils/build-script` (we will introduce this shortly)
   is a high-level build automation script that supports options such as
   building a Swift-compatible LLDB,
   building the Swift Package Manager,
   building for various platforms,
   running tests after builds, and more.

Phew, that's a lot to digest.
Now let's proceed to the actual build itself!

### The actual build

1. Make sure you have Sccache running.
   ```
   sccache --start-server
   ```
2. Decide if you would like to build the compiler using Ninja or using Xcode.
   - If you use an editor other than Xcode and/or you want somewhat faster builds,
     go with Ninja.
   - If you are comfortable with using Xcode and would prefer to use it,
     go with Xcode.
3. Build the compiler with optimizations, debuginfo, assertions and run the tests.
   - Via Ninja:
     ```
     utils/build-script --skip-build-benchmark \
       --cmake-c-launcher="$(which sccache)" --cmake-cxx-launcher="$(which sccache)" \
       --release-debuginfo --assertions --test
     ```
   - Via Xcode:
     ```
     utils/build-script --skip-build-benchmark \
       --cmake-c-launcher="$(which sccache)" --cmake-cxx-launcher="$(which sccache)" \
       --release-debuginfo --assertions --test \
       --xcode
     ```
   This will create a directory
   `swift-project/build/Ninja-RelWithDebInfoAssert`
   (with `Xcode` instead of `Ninja` if you used `--xcode`)
   containing the build artifacts.
   Once the build is complete, it will run the tests.
   The tests should be passing. If that's not the case:
   - Consider [filing a bug report](https://swift.org/contributing/#reporting-bugs).
   - Note down which tests are failing as a baseline.
     This baseline will be handy later when you run the tests after making a change.

## Editing code

<!-- Describe where to find xcodeproj and which schemas to use -->
<!-- Describe small changes to version string -> recompile -> check -->

<!-- ### Incremental rebuilds with Ninja -->

<!-- ### Incremental rebuilds with Xcode -->

## Running tests

<!-- briefly describe running tests with utils/run-test -->

<!-- link to Testing.md -->

## Debugging issues

<!-- briefly describe
  print debugging
  debugging using Xcode debugger
  commandline lldb
-->

<!-- link to DebuggingTheCompiler.md -->

## Next steps

<!-- link to Compiler Pipeline -->
<!-- link to LLVM style guide -->
<!-- link to LLVM programmer's manual -->
<!-- talk about Clang format diff? -->
<!-- bring up Testing.md and DebuggingTheCompiler.md again -->
* Check out the [development tips](../DevelopmentTips.md) for better productivity.

<!--
### Installing sccache

If you anticipate needing the build the Swift toolchain frequently,
we recommend that you install [`sccache`][sccache]
for caching between builds.
This means that if you ever delete your build directory and rebuild from scratch,
the rebuild will proceed much faster.

[`ccache`][ccache] can also be used instead of `sccache`
(there should not be any functional difference).
For simplicity, we'll refer to `sccache` in the rest of this guide.
You can substitute `sccache` with `ccache` if you installed the latter.

You can install `sccache` using your package manager
or by following the instructions in their [README][sccache].
Start `sccache` using `sccache --start-server`.
That's enough to get going.
You can find more details about using `sccache` in
[docs/DevelopmentTips.md](../DevelopmentTips.md#use-sccache-to-cache-build-artifacts)

[sccache]: https://github.com/mozilla/sccache
[ccache]: https://ccache.dev
-->
