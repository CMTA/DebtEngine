#!/bin/bash
cd "$(dirname "$0")/../.."
DIR=$(pwd)
DIR_OUT=${DIR}/doc/surya/surya_inheritance
if ! [ -d "$DIR_OUT" ]; then
    mkdir -p ./doc/surya/surya_inheritance
fi
cd './src'
DIR=$(pwd)
for i in $(find . -type f);
do
    filename=${i##*/}
    ext=${i##*.}
    if [[ $ext == 'sol' ]]; then
        npx surya inheritance $i | dot -Tpng > ../doc/surya/surya_inheritance/surya_inheritance_$filename.png;
    fi
done;