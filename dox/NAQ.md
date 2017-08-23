**Some Guy**

Q: *So why would anyone use this ? If I need some dependencies I'll use `brew` or `apt-get` "install" and I am good to go.*

A: Yes that's generally easier, but it has a few drawbacks. If you have two
projects on the same machine, and both use sqlite for example, both versions
must compile with the same version and are affected by an upgrade. You
lose track of what your dependencies for your project are and if you want to
share your project you must document, what prerequisites to install.
Then there are projects, that are too new, that you can't even get via
`apt-get` or `brew`. And some dependencies may be your own even.

Q: *As a user I really don't run into these situations ever!*

A: That's why it's billed as a dependency manager for developers.


**Developer**

Q: *I just use a VM/docker/jail for this!*

A: Sure go ahead, install that 4 GB development environment a couple of times
and see it getting old real fast.

Q: *Isn't this slow ? You'd have to clone these dependencies for every project, that uses mulle-bootstrap ?*

A: mulle-bootstrap can use a local git mirror to speed up those clones quite considerably. 


**Yet another Developer**

Q: *So as I understand it `mulle-bootstrap` basically does*

```
   for url in ${urls}
   do
       git clone "${url}"
   done
```

*Why does it need 20K lines of shellscript to do that ?*

A: Well it basically does

```
   for url in ${urls}
   do
      name="`basename -- ${url} .git`"
      git clone -d "${name}" "${url}"
      (
         cd "${name}" ;
         make install
      )
   done
```

which is already twice as many lines, so that's already closer to 20K.

Q: *I count 9 lines, there must be something more going on in the rest of the code ?*

A: Ah yes, well there is also some code to clean up after the fact. The rest is pretty much housekeeping and some useful gimmicks.

Q: *OK, whatever. If you don't want to answer it. Fine.*

A: It's just more than can be said in a line or ten. And actually most of the code *is* dedicated to housekeeping.


**Another developer**

Q: *I have no idea what it does, and how it does it. But I already have a problem. One of the repositories is a svn repository. The whole scheme fails!*

A: Actually `mulle-bootstrap` can deal with svn. It can also deal with tar and
zip archives. If you have some format that `mulle-bootstrap` doesn't support
you can "easily" write a script to clone it (or even write a scm-plugin for mulle-bootstrap).

Q: *I see myself hitting the next wall pretty soon. But OK. So the svn repository doesn't even use* **make** *it's using*  **autoconf**. *What now ?*

A: `mulle-bootstrap` can deal with cmake, configure, autoconf and
xcodeproj (on macos) on its own. If it doesn't work out, you can always use a script.

Q: *Yeah another script...*

A: Well you also could write a plugin for the mulle-bootstrap build system :)

Q: *Ha, ha. mulle-bootstrap is a lie. It can't really do Makefile based projects!*

A: Yes, you caught me. The problem is that there is no universal way to specify
an install prefix for Makefiles. That's why mulle-bootstrap needs a Makefile
wrapper like autoconf, configure or cmake.


**Another Developer**

Q: *Lo and behold, I cloned a project written by someone who also uses
`mulle-bootstrap`. Now I got a lot of other stuff suddenly in my dependencies!*

A: This is where the dependency manager part in the project claim, really hits
twice. Not only does it manage your dependencies, it also manages the
dependencies of your dependencies.

Q: *Isn't it more or less chance, that things are compiled in the right order ?*

A: It shouldn't be. `mulle-bootstrap` contains a dependency resolver to order
dependencies according to intended build order.



**Yet another Developer**

Q: *What's the deal with cross-platform ?*

A: Ideally your mulle-bootstrap setup works on all participating platforms.
mulle-bootstrap is written in bash script, so whereever you have a bash it
should work!

Q: *Yeah sure. That won't work in a million years.*

A: Well on a per-project basis, you may need to tweak things for each platform.
But mulle-bootstrap allows you per-platform settings and scripts. So you could
run a `build.sh` script on macos and a different `build.sh` on Windows for
example. Also it really helps if all the projects are cmake based...



**Another Developer**

Q: *Damn the portability, I want some tools installed and I want them now. I'll use `brew` anyway.*

A: Not so fast, you could also install them "locally" with `mulle-bootstrap`
using brews. That gets you the best of both worlds, project-local dependencies,
that are pre-compiled by homebrew.

Q: *Do brews also work on Linux ?*

A: In terms of apt-get, not yet. In terms of linuxbrew, yes... quite likely... often... sometimes

Q: *Do brews also work on FreeBSD and Windows ?*

A: No


**Yet another Developer**

Q: *So my own project is written in cmake. I have to remember to mulle-bootstrap
and then cmake and make everytime. Can this be even more convenient ?*

A: You could give mulle-build a try.

Q: *So isn't this* **mulle-build** *thing just doing*

```
   mulle-bootstrap
   mkdir build
   cd build
   cmake ..
   make
```
A: Yes pretty much

Q: *What are the other 1500 lines of code doing ?*

A: Let's not go there...


**Another Developer**

Q: *This is just not as convenient as a python environment ? Why can it be not more like a python environment.*

A: You could give **mulle-sde** a try.


**Advanced Developer**

Q: *I mean the program isn't half bad, and I used it quite a bit. But installing all these dependencies for every hello world project is tedious to say the least!*

A: Rejoice! mulle-bootstrap can be configured in a master/minion setup, where each project shares the dependencies with other projects in a common master project.

