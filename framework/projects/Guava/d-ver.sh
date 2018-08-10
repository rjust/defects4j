#!/bin/bash
cd $1

cat pom.xml | while read line
do 
	
	if [ "$line" == "<artifactId>mockito-core</artifactId>" ];then
		read line 
		echo $line > temfile
		val=`cat temfile | grep -o -P '(?<=<version>).*(?=</version>)'`
		cp $2/mockito-core-$val.jar $1/compileLib/
		rm temfile
		break
	fi
done


cat pom.xml | grep -o -P '(?<=<truth.version>).*(?=</truth.version>)' > truth-ver.txt
cat truth-ver.txt | while read line
do 
	cp $2/truth-$line.jar $1/compileLib/
done
rm truth-ver.txt

cat pom.xml | while read line
do 
	if [ "$line" == "<artifactId>truth-java8-extension</artifactId>" ];then
		cp $2/truth-java8-extension-0.31.jar $1/compileLib/
		break;
	fi
done
