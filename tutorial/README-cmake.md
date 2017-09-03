
# "a b c" Tutorial

> This tutorial shows you how to orchestrate your own libraries during
> developement.

This directory contains a simple test with 3 folders `a`, `b`,  `c`. Each folder
contains a minimal C-language project of the same name.  Project **c** depends
on **b**. And project **b** depends on **a**.

## First failing try without mulle-bootstrap

Initially none of the folders contain a `.bootstrap` folder.

Try to build **b** with `cmake`. The first run of **cmake** will produce the
Makefile which you can then **make**.

```console
cd b
( mkdir build ; cd build ; cmake -G "Unix Makefiles" .. ; make )
```

> On Windows with the MingGW bash, use "NMake Makefiles" and nmake instead
>
> ```console
> cd b
> ( mkdir build ; cd build ; `cmake -G "NMake Makefiles" .. ; nmake`)
> ```

 It will not work, because the header
`<a/a.h>` will not be found.


## mulle-bootstrap to the rescue

While being still in **b**:

```console
mulle-bootstrap init -n
```

Now add a repository. You can use an absolute path:

```
mulle-bootstrap repository add "${PWD}/../a"
```

Alright, ready to bootstrap.


```console
mulle-bootstrap --symlinks
```


> On Windows in the MingGW bash, this will not work, because there
> is no symlink support. You have to place 'a' under **git** control first
>
> ```
> (
>   cd ../a;
>   git init ;
>   git add . ;
>   git commit -m "Mercyful Release"
> )
> mulle-bootstrap
> ```


Check out the contents of the `b/dependencies` folder.
It should contain the following files (`ls -GFR dependencies`):

~~~
Frameworks/ include/    lib/

dependencies/Frameworks:

dependencies/include:
a/

dependencies/include/a:
a.h

dependencies/lib:
libA.a
~~~

> On Windows in the MingGW bash, the library will be `a.lib`


## Building **b**

We need to modify b's `CMakeLists.txt` to use `dependencies/lib` and
`dependencies/include` as search paths.


Put these lines into the `CMakeLists.txt` file to add the proper search paths:

```
include_directories( BEFORE SYSTEM
   dependencies/include
)

link_directories( ${CMAKE_BINARY_DIR}
   dependencies/lib
)
```

So that the file looks like this now:

`CMakeLists.txt`:

```
cmake_minimum_required (VERSION 3.0)

project (b)

include_directories( BEFORE SYSTEM
   dependencies/include
)

link_directories( ${CMAKE_BINARY_DIR}
   dependencies/lib
)

set(HEADERS
src/b.h)

add_library(b
src/b.c
)

target_link_libraries( b LINK_PUBLIC a)

INSTALL(TARGETS b DESTINATION "lib")
INSTALL(FILES ${HEADERS} DESTINATION "include/b")
```

Now **b** will be able to build:

```
( cd build ; cmake -G "Unix Makefiles" .. ; make )
```

> Windows Mingw: `( cd build ; cmake -G "NMake Makefiles" .. ; nmake )`


## Inheriting your work in **c**

Now let's do the same for `c`:

> Windows Mingw: Before you do this put **b** into git. Do not add the
> `build` folder, the `addictions` folder or the `dependencies` folder.
> Add the `.bootstrap` folder and all other required files, but ignore the
> `.bootstrap.auto` folder.
>
> ```
> git init
> git add src/ b.xcodeproj/ CMakeLists.txt .bootstrap
> git commit -m "Mercyful Release"
> ```

This time just to be different, lets use a relative path and update the
`search_path`:

```console
mulle-bootstrap init -n
mulle-bootstrap repository add b
mulle-bootstrap config -a --simplify search_path "${PWD}/..:`mulle-bootstrap config search_path`"
```

mulle-bootstrap will have used the dependency information from **b**, to
automatically also build **a** for you in the proper order.

Since the `CMakeLists.txt` file of **c** is already setup properly, you can now just build and run **c**:

```
mkdir build 2> /dev/null
( cd build ;
cmake -G "Unix Makefiles" .. ;
make ;
./c )
```

> Windows:
> ```
> mkdir build 2> /dev/null
> ( cd build ;
> cmake -G "NMake Makefiles" .. ;
> nmake ;
> ./c.exe )
```





