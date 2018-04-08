#!/bin/bash
# parameters $1: directory of the compiled assets
#            $2: program name
if [ ! -d "$1" ] ; then
  >2&1 echo "directory $1 does not exist"
  exit 1
fi
#we create a temp dir (simulating the sandbox dir)
MYTEMP=`mktemp -d`
cp "$1"/.*.42* "$MYTEMP/" 2>/dev/null
cp "$1"/*.42* "$MYTEMP/" 2>/dev/null
cp "$1"/*.4st "$MYTEMP/" 2>/dev/null
cp "$1"/*.4ad "$MYTEMP/" 2>/dev/null
cp "$1"/*.4tm "$MYTEMP/" 2>/dev/null
cp "$1"/*.4tb "$MYTEMP/" 2>/dev/null
cp "$1"/*.unl "$MYTEMP/" 2>/dev/null
cp "$1"/*.4sm "$MYTEMP/" 2>/dev/null
cp "$1"/*.data "$MYTEMP/" 2>/dev/null
cp "$1"/*.test "$MYTEMP/" 2>/dev/null
cp "$1"/*.sch "$MYTEMP/" 2>/dev/null
cp "$1"/*.png "$MYTEMP/" 2>/dev/null
export FGLIMAGEPATH=$MYTEMP:$FGLIMAGEPATH
cd "$MYTEMP"
if [ -f "$1"/main.args ] ; then
  MYARGS=`cat "$1"/main.args`
fi
fglrun "$2" $MYARGS
RETVAL=$?
cd - >/dev/null
rm -rf "$MYTEMP"
exit $RETVAL
