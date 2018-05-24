# mulle-make, 🤖 Build projects uniformly with a variety of build systems

![Last version](https://img.shields.io/github/tag/mulle-sde/mulle-make.svg)

... for Linux, OS X, FreeBSD, Windows

**mulle-make** will determine if the project needs to
be build via `configure`, `autoconf`, `cmake` or some other build tool.
It will then proceed to build the project using that tool.

![](dox/mulle-sde-overview.png)


Executable   | Description
-------------|--------------------------------
`mulle-make` | Build a single project


## Install

### Manually

Install the pre-requisites:

* [mulle-bashfunctions](https://github.com/mulle-nat/mulle-bashfunctions)


Install latest version into `/usr` with sudo:

```
curl -L 'https://github.com/mulle-sde/mulle-make/archive/latest.tar.gz' \
 | tar xfz - && cd 'mulle-make-latest' && sudo ./install /usr
```

### Packages

OS    | Command
------|------------------------------------
macos | `brew install mulle-kybernetik/software/mulle-make`



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

But it can do this for an expandable variety of build tools.


## Project structure

The next picture gives an overview of `mulle-make` default project structure
and how to customize it:

![](dox/overview.png)


## GitHub and Mulle kybernetiK

The development is done on
[Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-make/master).
Releases and bug-tracking are on [GitHub](https://github.com/mulle-sde/mulle-make).
