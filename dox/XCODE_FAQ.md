## Xcode problems


### I have a depencency on another library in the same project.

But the headers of the dependency library are in `dependencies/usr/local/include`.
What now ?

**mulle-bootstrap*+ can't manage xcodebuild dependencies, so you have to help
it. Specify the targets you want to build or set the proper dependencies in the
xcode project.


### My Xcode project's headers do not show up ?

Check that your Xcode project has a **Header Phase** and that the header files
are in "public".



### I specified SKIP_INSTALL=YES in my Xcode project, but stuff gets installed nonetheless ?

Because this SKIP_INSTALL=YES is the default unfortunately and lots of project
maintainers forget to turn it off, **mulle-bootstrap** sets this flag to NO at
compile time. If you know that SKIP_INSTALL is correctly set, set
"xcode_proper_skip_install" to "YES".

```console
mkdir -p  ".bootstrap/{reponame}" 2> /dev/null
echo "YES" > .bootstrap/{reponame}/proper_skip_install
```


### I build an aggregate target and the headers end up in the wrong place

mulle_bootstrap has problems with aggregate targets. Built the subtargets
individually by enumerating them in ".bootstrap/{reponame}/targets"


```console
mkdir -p  ".bootstrap/MulleScion" 2> /dev/null
echo "MulleScion (iOS Library)
MulleScion (iOS Framework)" > .bootstrap/MulleScion/targets"
```

