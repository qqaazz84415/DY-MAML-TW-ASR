#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->
dir_am_base=$dir_target_base/am_gmm
dir_ali=alignment

# result

# ---------------------------------------------------------
# <--- Parameter --->

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "==========================================================================="
echo "=                        get frame level alignment                        ="
echo "==========================================================================="

for x in ca en jp md th
do
  for ((i=1; i<=8; i=i+1))
  do
      cp ${dir_am_base}_${x}/monophone/ali.${i}.gz ${dir_am_base}_${x}/monophone/ali.${i}.gz.bak
      [ -f $dir_ali/$x/ali.${i} ] && rm -f $dir_ali/$x/ali.${i}
      [ -f $dir_ali/$x/ali.${i}.txt ] && rm -f $dir_ali/$x/ali.${i}.txt
      gunzip -c ${dir_am_base}_${x}/monophone/ali.${i}.gz > $dir_ali/$x/ali.${i}
      mv ${dir_am_base}_${x}/monophone/ali.${i}.gz.bak ${dir_am_base}_${x}/monophone/ali.${i}.gz
  done
done

for x in ca en jp md th
do
  for ((i=1; i<=8; i=i+1))
  do
    show-alignments ${dir_am_base}_${x}/monophone/phones.txt ${dir_am_base}_${x}/monophone/final.mdl ark:$dir_ali/$x/ali.${i} > $dir_ali/$x/ali.${i}.txt
  done
done