#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# result

# ---------------------------------------------------------
# <--- Parameter --->
dir=$1
min_lmwt=$2
max_lmwt=$3
wip=$4

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "===> Changing phrase into words for penalty $wip <==="
for ((i=$min_lmwt; i<=$max_lmwt; i++))
do
  cat $dir/scoring_kaldi/penalty_${wip}/$i.txt |\
    steps/nnet3/chain/e2e/text_to_phones.py $dir_source_base/lang > $dir/scoring_kaldi/penalty_${wip}/${i}_p_tmp.txt
done

cat $dir/scoring_kaldi/test_filt.txt |\
  steps/nnet3/chain/e2e/text_to_phones.py $dir_source_base/lang > $dir/scoring_kaldi/test_filt_p_tmp.txt