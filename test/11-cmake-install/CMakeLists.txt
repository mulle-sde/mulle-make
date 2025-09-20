cmake_minimum_required( VERSION 3.13...99.99)

project( mytest C)


add_executable( myexe
main.c
)

add_library( mylib
mylib.c)


install( TARGETS "myexe" DESTINATION "bin")
install( TARGETS "mylib" DESTINATION "lib")
install( FILES "mylib.h" DESTINATION "include")