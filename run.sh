#! /bin/bash

curDir=`pwd`
# get shell direction

workDir=$curDir
echo $workDir
cd $workDir

bash ./sync.sh

mkdocs gh-deploy

cd $curDir
