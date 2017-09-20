# mulle-bootstrap, cross platform dependency manager using bash

![Last version](https://img.shields.io/github/tag/mulle-nat/mulle-bootstrap.svg)

... for Linux, OS X, FreeBSD, Windows

... for C, C++, Objective-C

... certainly not a "minimal" or "lightweight" project with ca. 20000 lines of
  shell script code


## Why you may want it

* You program in C, C++ or in Objective-C, **mulle-bootstrap** is written for you
* If you need to link against a library, that clashes with an installed
library,  **mulle-bootstrap** could break this quandary
* If you feel that `apt-get install` pollutes your system with too many libraries,  **mulle-bootstrap** may be the solution
* If you don't like developing in virtual machines, **mulle-bootstrap** may
tickle your fancy
* If you like to decompose huge projects into reusable libraries,
**mulle-bootstrap** may enable you to do so
* If you do cross-platform development, **mulle-bootstrap** may be your best bet for a dependency manager


#### Read the [NAQ](dox/NAQ.md) for a quick introduction

> #### OS X/Linux: Quick install with homebrew/linuxbrew
>
> ```console
> brew install mulle-kybernetik/software/mulle-bootstrap
> ```
> Other platforms see [How to install](dox/INSTALL.md) for install
> instructions.
>

## A first use

So you need zlib and expat to link against in your own project ? No problem:

```
mulle-bootstrap init
mulle-bootstrap repositories add 'https://github.com/madler/zlib.git'
mulle-bootstrap repositories add 'https://github.com/coapp-packages/expat.git'
mulle-bootstrap
```

**mulle-bootstrap** will clone both into a common directory `stashes`.

After cloning **mulle-bootstrap** looks for a `.bootstrap` folder in the freshly checked out repositories. They could have dependencies too. (If they
did, those dependencies would be now also added and fetched).

Everything is now inplace so **mulle-bootstrap** can build both libraries. It will place the installable headers and the libraries into the `dependencies/lib` and `dependencies/include` folders.

## Core principles

* Nothing gets installed outside of the project folder
* **mulle-bootstrap** manages your dependencies, it does not manage your
project
* It should be adaptable to a wide ranges of project styles. Almost anything
can be done with configuration settings or additional shell scripts.
* It should be scrutable. If things go wrong, it should be easy to figure
out what the problem is. It has extensive logging and tracing support built in.
* It should run everywhere. **mulle-bootstrap** is a collection of
shell scripts. If your system can run the bash, it can run **mulle-bootstrap**.


## What it does technically

* downloads [zip](http://eab.abime.net/showthread.php?t=5025) and [tar](http://www.grumpynerd.com/?p=132) archives
* fetches [git](//enux.pl/article/en/2014-01-21/why-git-sucks) repositories and it can also checkout [svn](//andreasjacobsen.com/2008/10/26/subversion-sucks-get-over-it/).
* builds [cmake](//blog.cppcms.com/post/54),
[xcodebuild](//devcodehack.com/xcode-sucks-and-heres-why/) and
[autoconf/configure](//quetzalcoatal.blogspot.de/2011/06/why-autoconf-sucks.html)
projects and installs their output into a "dependencies" folder.
* installs [brew](//dzone.com/articles/why-osx-sucks-and-you-should) binaries and
libraries into an "addictions" folder (on participating platforms)
* alerts to the presence of shell scripts in fetched dependencies


## Tell me more

* The [WIKI](https://github.com/mulle-nat/mulle-bootstrap/wiki) should be your first stop, when looking for in-depth information about mulle-bootstrap.


## A first use

So you need a bunch of third party projects to build your own
project ? No problem. Use **mulle-bootstrap init** to do the initial setup of
a `.bootstrap` folder in your project directory. Then add the git repository
URLs:

```
mulle-bootstrap init
mulle-bootstrap setting -g -r -a "repositories" "https://github.com/madler/zlib.git"
mulle-bootstrap setting -g -r -a "repositories" "https://github.com/coapp-packages/expat.git"
mulle-bootstrap
```

**mulle-bootstrap** will check them out into a common directory `stashes`.

After cloning **mulle-bootstrap** looks for a `.bootstrap` folder in the freshly
checked out repositories. They might have dependencies too, if they do, those
dependencies are added and also fetched.

Everything should now be in place so **mulle-bootstrap** that can now build the
dependencies. It will place the headers and the produced
libraries into the `dependencies/lib`  and `dependencies/include` folders.


## Tell me more

* [How to install](dox/INSTALL.md)
* [How to use it](dox/COMMANDS.md)
* [What has changed ?](RELEASENOTES.md)
* [Tweak guide](dox/SETTINGS.md)
* [CMakeLists.txt.example](dox/CMakeLists.txt.example) shows how to access dependencies from **cmake**
* [FAQ](dox/FAQ.md)
* [Releasenotes](RELEASENOTES.md)


## GitHub and Mulle kybernetiK

The development is done on [Mulle kybernetiK](https://www.mulle-kybernetik.com/software/git/mulle-bootstrap/master). Releases and bug-tracking are on [GitHub](https://github.com/mulle-nat/mulle-bootstrap).


