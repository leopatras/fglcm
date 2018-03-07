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
cp "$1"/*.4sm "$MYTEMP/" 2>/dev/null
cd "$MYTEMP"
fglrun "$2"
RETVAL=$?
cd -
rm -rf "$MYTEMP"
exit $RETVAL
