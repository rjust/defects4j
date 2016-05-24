#!/bin/bash
# Gregory Gay (greg@greggay.com)
# Ensures the correct version of the byte-buddy dependency is used at compile time
# $1 = builddir
# $2 = scriptdir

cd $1
./gradlew dependencies >> tmpDepend.txt
version=`cat tmpDepend.txt | grep buddy | cut -d: -f 3 | head -1`
cp $2/build-scripts/Mockito/byte-buddy/byte-buddy-$version.jar $1/compileLib/
rm tmpDepend.txt
