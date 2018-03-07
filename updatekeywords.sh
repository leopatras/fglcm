#!/bin/bash
#we create a new 4gl.js based on fgl.vim
if [ -z "$FGLDIR" ] ; then
  echo "FGLDIR must be set"
  exit 1
fi

if [ "$1" == "4gl" ] ; then
  if [ -f "$FGLDIR/lib/fgl.vim" ] ; then
    FGLVIM="$FGLDIR/lib/fgl.vim"
  fi
  if [ -f "$FGLDIR/vimfiles/syntax/fgl.vim" ] ; then
    FGLVIM="$FGLDIR/vimfiles/syntax/fgl.vim"
  fi
elif [ "$1" == "per" ] ; then
  if [ -f "$FGLDIR/lib/per.vim" ] ; then
    FGLVIM="$FGLDIR/lib/per.vim"
  fi
  if [ -f "$FGLDIR/vimfiles/syntax/per.vim" ] ; then
    FGLVIM="$FGLDIR/vimfiles/syntax/per.vim"
  fi
fi

if [ -z "$FGLVIM" ] ; then
  echo "can't find $1.vim"
  exit 1
fi
cat $FGLVIM | sed -n '/^syn keyword/p' | awk 'BEGIN {start=1;print("var keywords={");} { if (start==1) { start=0;printf("\"%s\":true\n",$4);} else { printf(",\"%s\":true\n",$4);}} END {print("}//keywords\n");}' > keywords.js
if [ $? -ne 0 ] ; then
  echo "can't get keywords"
  exit 1
fi
#cat 4gl.js | awk -f mix.awk > webcomponents/fglcm/codemirror/mode/4gl/4gl.js
cat $1.js | awk -f mix.awk
