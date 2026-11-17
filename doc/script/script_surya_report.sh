#!/bin/bash
cd "$(dirname "$0")/../.."
DIR=$(pwd)
DIR_OUT=${DIR}/doc/surya/surya_report
if ! [ -d "$DIR_OUT" ]; then
    mkdir -p ./doc/surya/surya_report
fi
cd './src'
DIR=$(pwd)
for i in $(find . -type f);
do
    filename=${i##*/}
    ext=${i##*.}
    if [[ $ext == 'sol' ]]; then
        npx surya mdreport ../doc/surya/surya_report/surya_report_$filename.md $i;
    fi
done;