#!/bin/bash

if [ ! $# -eq 2 ]; then
    echo "Usage: ./createSwiftUISimpleScreen.sh Folder MyScreenName"
    exit 1
fi

MODULE_DIR="../../SendingnNetworkSwiftUI/Modules"
OUTPUT_DIR=$MODULE_DIR/$1
SCREEN_NAME=$2
SCREEN_VAR_NAME=`echo $SCREEN_NAME | awk '{ print tolower(substr($0, 1, 1)) substr($0, 2) }'`
TEMPLATE_DIR=$MODULE_DIR/Template/SimpleScreenExample/
if [ -e $OUTPUT_DIR ]; then
    echo "Error: Folder ${OUTPUT_DIR} already exists"
    exit 1
fi

echo "Create folder ${OUTPUT_DIR}"

mkdir -p $OUTPUT_DIR
cp -R $TEMPLATE_DIR $OUTPUT_DIR/

cd $OUTPUT_DIR
for file in $(find * -type f -print)
do
  echo "Building ${file/TemplateSimpleScreen/$SCREEN_NAME}..."
  perl -p -i -e "s/TemplateSimpleScreen/"$SCREEN_NAME"/g" $file
  perl -p -i -e "s/templateSimpleScreen/"$SCREEN_VAR_NAME"/g" $file

  mv ${file} ${file/TemplateSimpleScreen/$SCREEN_NAME}
done
