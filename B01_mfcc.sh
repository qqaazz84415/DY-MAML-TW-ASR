#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_data=$dir_data_train  # dir contains text, wav.scp, utt2spk
dir_mfcc=$dir_source_feat_mfcc

rm -rf $dir_mfcc
mkdir -p $dir_mfcc
cp -r $dir_data $dir_mfcc/train

# ---------------------------------------------------------
# <--- Parameter --->

mfcc_config=conf/mfcc_hires.conf  # high-resolution MFCC

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                             MFCC Extraction                              ="
echo "============================================================================"

echo "===> execute utils/utt2spk_to_spk2utt.pl <==="
utils/utt2spk_to_spk2utt.pl $dir_mfcc/train/utt2spk > $dir_mfcc/train/spk2utt || exit 1;

echo "===> execute steps/make_mfcc.sh <==="
steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config $mfcc_config \
  $dir_mfcc/train $dir_mfcc/log $dir_mfcc/scp_ark || exit 1;

echo "===> execute steps/compute_cmvn_stats.sh <==="
steps/compute_cmvn_stats.sh $dir_mfcc/train $dir_mfcc/log $dir_mfcc/scp_ark || exit 1;

echo "===> execute utils/fix_data_dir.sh <==="
utils/fix_data_dir.sh $dir_mfcc/train || exit 1;

# ---------------------------------------------------------

echo ""
echo "*********************************"
echo "***** MFCC Extraction Done. *****"
echo "*********************************"
