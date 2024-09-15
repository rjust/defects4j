#!/bin/bash
# Gregory Gay (greg@greggay.com)
# Ensures the correct version of the byte-buddy dependency is used at compile time
# $1 = workDir
# $2 = D4J_HOME

cd "$1" || { echo "cannot cd to workdir $1"; exit 2; }
./gradlew dependencies >> tmpDepend.txt
if grep -q buddy tmpDepend.txt; then
    version=$(grep buddy tmpDepend.txt | head -1 | cut -d: -f 3)
    cp "$2/framework/projects/Mockito/byte-buddy/byte-buddy-$version.jar" "$1/compileLib/"
fi
rm tmpDepend.txt
