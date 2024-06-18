#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# if you need to train from the beginning, uncomment the following two lines for the first time
# then comment them from second time on to preserve the data
# mkdir -p $dir_source_base
# mkdir -p $dir_target_base

# ---------------------------------------------------------
# <--- Record the Setting & Execute Logs --->

dt=$(date '+%Y-%m-%d_%H-%M-%S');
dir_log=$dir_log_base/log_${dt}

mkdir -p $dir_log
mkdir -p $dir_log/sh
cp $dir_proj_base/*.sh $dir_log/sh

# ---------------------------------------------------------
# <--- Execute Scripts --->
# Why pretrain GMM -> get ali -> train TDNN? : https://groups.google.com/forum/#!msg/kaldi-help/-izj3NYAdDw/0Ht6_STqBgAJ
# ./A01_lang.sh 2>&1 | tee $dir_log/A01_lang.log || exit 1;
# # lm_ngram_combine is for Mandarin and Taiwanese combined lm, so we don't use it in Taiwanese recognition
# ./A02_lm_ngram.sh 2>&1 | tee $dir_log/A02_lm_ngram.log || exit 1;
# ./A02_lm_ngram_combine.sh 2>&1 || exit 1;  # ignore the log file of this script since it's for code-switching and the log will be really big(up to 30G)

# ./B01_mfcc.sh 2>&1 | tee $dir_log/B01_mfcc.log || exit 1;
# ./B02_am_gmm.sh 2>&1 | tee $dir_log/B02_am_gmm.log || exit 1;
# ./B03_gmm_hmm.sh 2>&1 | tee $dir_log/B03_gmm_hmm.log || exit 1;

# ./C01_ivector.sh 2>&1 | tee $dir_log/C01_ivector.log || exit 1;
# ./C02_am_tdnn.sh 2>&1 | tee $dir_log/C02_am_tdnn.log || exit 1;
# ./C03_tdnn_hmm.sh 2>&1 | tee $dir_log/C03_tdnn_hmm.log || exit 1;

./D01_decoding.sh 2>&1 | tee $dir_log/D01_decoding.log || exit 1;

# ---------------------------------------------------------

echo ""
echo "*********************"
echo "***** All Done. *****"
echo "*********************"

