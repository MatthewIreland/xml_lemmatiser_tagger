#!/bin/sh

rm -rf run/in
cp -r data/whole_corpus run/
mv run/whole_corpus run/in


find ./run/in -type f -name "*.xml" -print0 | xargs -0 dos2unix

find ./run/in -name '*.xml' -exec sed -i "s/<\/p>//g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/<p>//g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/<\/sp>//g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/<sp>//g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/&lt;/ /g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/&gt;/ /g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/—/ /g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/（/ /g" {} +
find ./run/in -name '*.xml' -exec sed -i "s/）/ /g" {} +
