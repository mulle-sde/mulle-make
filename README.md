# mulle-make, 🤖 Build projects uniformly with a variety of build systems

![Last version](https://img.shields.io/github/tag/{{PUBLISHER}}/mulle-make.svg)

... for Linux, OS X, FreeBSD, Windows

**mulle-make** will determine if the project needs to
be build via `configure`, `autoconf`, `cmake` or some other build tool.
It will then proceed to build the project using that tool.


Executable   | Description
-------------|--------------------------------
`mulle-make` | Build a single project


## Install

OS    | Command
------|------------------------------------
macos | `brew install mulle-kybernetik/software/mulle-make`
other | ./install.sh  (Requires: [mulle-bashfunctions](https://github.com/mulle-nat/mulle-bashfunctions))

## What **mulle-make** does

Essentially, **mulle-make** does:

```
src="`find ${PROJECT_DIR} --name "CMakeLists.txt -print`"
cd "${src}"
mkdir build
cd build
cmake ..
ninja
```

But that's really not all. :) It's provides a uniform call interface to various build tools.


## GitHub and Mulle kybernetiK

The development is done on
[Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-make/master).
Releases and bug-tracking are on [GitHub](https://github.com/{{PUBLISHER}}/mulle-make).
