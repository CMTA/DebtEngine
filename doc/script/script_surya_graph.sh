#!/bin/bash
cd "$(dirname "$0")/../.."
DIR=$(pwd)
DIR_OUT=${DIR}/doc/surya/surya_graph
if ! [ -d "$DIR_OUT" ]; then
    mkdir -p ./doc/surya/surya_graph
fi
cd './src'
DIR=$(pwd)
for i in $(find . -type f);
do
    #echo $i
    filename=${i##*/}
    ext=${i##*.}
    if [[ $ext == 'sol' ]]; then
        npx surya graph $i | dot -Tpng > ../doc/surya/surya_graph/surya_graph_$filename.png;
    fi
done;