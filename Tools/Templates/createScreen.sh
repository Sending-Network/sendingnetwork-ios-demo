#!/bin/bash

if [ ! $# -eq 2 ]; then
    echo "Usage: ./createScreen.sh Folder MyScreenName"
    exit 1
fi 

OUTPUT_DIR="../../SendingnNetwork/Modules"/$1
SCREEN_NAME=$2
SCREEN_VAR_NAME=`echo $SCREEN_NAME | awk '{ print tolower(substr($0, 1, 1)) substr($0, 2) }'`

MODULE_DIR="../../SendingnNetwork/Modules"

if [ -e $OUTPUT_DIR ]; then
    echo "Error: Folder ${OUTPUT_DIR} already exists"
    exit 1
fi 

echo "Create folder ${OUTPUT_DIR}"

mkdir -p $OUTPUT_DIR
cp -R buildable/ScreenTemplate/ $OUTPUT_DIR/

cd $OUTPUT_DIR
for file in *
do
    echo "Building ${file/TemplateScreen/$SCREEN_NAME}..."
    perl -p -i -e "s/TemplateScreen/"$SCREEN_NAME"/g" $file
    perl -p -i -e "s/templateScreen/"$SCREEN_VAR_NAME"/g" $file
    
    if [[ ! $file == *.storyboard ]];
    then
        echo "// $ createScreen.sh $@" | cat - ${file} > /tmp/$$ && mv /tmp/$$ ${file}
        echo '// File created from ScreenTemplate' | cat - ${file} > /tmp/$$ && mv /tmp/$$ ${file}
    fi
    
    mv ${file} ${file/TemplateScreen/$SCREEN_NAME}
done