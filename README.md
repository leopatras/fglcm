#fglcm

fglcm - .4gl , .per remote editor with syntax highlighting and completion

# Motivation

The program is intended to be the backbone of the upcoming fglfiddle web site:
One should be able to develop/test Genero programs entirely in the browser.
It uses the codemirror editor javascript component to provide a decent editing experience. 
(See https://codemirror.net)
As a side effect it works in GDC too.

# Prerequisites
Gnu Make, nodejs and npm, under Linux a C-compiler is required

Call
```
$ make
```
to build fglcm, then
simply call
```
$ ./cm demo/foo.4gl
```
to edit a sample file with GDC.

Call
```
$ ./cmweb demo/foo.4gl
```
to edit a sample file in the browser.
(The GAS needs to be installed and FGLASDIR needs to be set)
Opening a .per file shows the live form preview right hand side.

# Installation

You don't necessarily need to install fglcm.
If you did check out this repository and once called make initially you can call
```
$ <path_to_this_repository>/cm <your source file>
```
and it uses the fglcomp/fglrun in your PATH to compile and run fglcm.
Of course you can add also <path_to_this_repository> in your PATH .

# fglfiddle mode

Set the environment variable *FGLFIDDLE* to enable the fiddle mode.
```
$ FGLFIDDLE=1 ./cm main.4gl
```
to let fglcm run in fiddle mode.
It has a main.4gl and a main.per file by default,
and shows a special toolbar to allow rapid switching between those 2 files.
