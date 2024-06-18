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
# ./A01_lang_meta.sh 2>&1 | tee $dir_log/A01_lang_meta.log || exit 1;
# ./A02_lm_ngram_meta.sh 2>&1 | tee $dir_log/A02_lm_ngram_meta.log || exit 1;

# ./B01_mfcc_meta.sh 2>&1 | tee $dir_log/B01_mfcc_meta.log || exit 1;
# ./B02_am_gmm_meta.sh 2>&1 | tee $dir_log/B02_am_gmm_meta.log || exit 1;
# ./B03_gmm_hmm_meta.sh 2>&1 | tee $dir_log/B03_gmm_hmm_meta.log || exit 1;

# ./C01_ivector_meta.sh 2>&1 | tee $dir_log/C01_ivector_meta.log || exit 1;
# ./C02_am_tdnn_meta_dIQ.sh 2>&1 | tee $dir_log/C02_am_tdnn_meta_dIQ.log || exit 1;
# ./C03_tdnn_hmm_meta.sh 2>&1 | tee $dir_log/C03_tdnn_hmm_meta.log || exit 1;

./D01_decoding_meta.sh 2>&1 | tee $dir_log/D01_decoding_meta.log || exit 1;

# ---------------------------------------------------------

echo ""
echo "*********************"
echo "***** All Done. *****"
echo "*********************"

