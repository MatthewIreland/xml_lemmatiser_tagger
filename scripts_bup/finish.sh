if [ -e out/all.vert ]; then
  rm out/all.vert
  echo -n "re-"
fi
echo "assembling vertical file"
find out/ -name "*.vert" ! -name "all.vert" -exec cat {} + >out/all.vert
echo "done"
