#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_data_md=$dir_data_base/train_md
dir_data_en=$dir_data_base/train_en
dir_data_ca=$dir_data_base/train_ca
dir_data_jp=$dir_data_base/train_jp
dir_data_th=$dir_data_base/train_th  # dir contains text, wav.scp, utt2spk
dir_mfcc_md=$dir_source_base/feature_mfcc_md
dir_mfcc_en=$dir_source_base/feature_mfcc_en
dir_mfcc_ca=$dir_source_base/feature_mfcc_ca
dir_mfcc_jp=$dir_source_base/feature_mfcc_jp
dir_mfcc_th=$dir_source_base/feature_mfcc_th

# rm -rf $dir_mfcc_md $dir_mfcc_en $dir_mfcc_ca $dir_mfcc_jp $dir_mfcc_th
# mkdir -p $dir_mfcc_md $dir_mfcc_en $dir_mfcc_ca $dir_mfcc_jp $dir_mfcc_th
rm -rf $dir_mfcc_en
mkdir $dir_mfcc_en
# cp -r $dir_data_ca $dir_mfcc_ca/train
# cp -r $dir_data_jp $dir_mfcc_jp/train
# cp -r $dir_data_th $dir_mfcc_th/train
cp -r $dir_data_en $dir_mfcc_en/train
# cp -r $dir_data_md $dir_mfcc_md/train

# ---------------------------------------------------------
# <--- Parameter --->

mfcc_config=conf/mfcc_hires.conf  # high-resolution MFCC

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                             MFCC Extraction                              ="
echo "============================================================================"

for x in en
do
  echo "===> execute utils/utt2spk_to_spk2utt.pl <==="
  utils/utt2spk_to_spk2utt.pl $dir_source_base/feature_mfcc_$x/train/utt2spk > $dir_source_base/feature_mfcc_$x/train/spk2utt || exit 1;

  echo "===> execute steps/make_mfcc.sh <==="
  steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config $mfcc_config \
    $dir_source_base/feature_mfcc_$x/train $dir_source_base/feature_mfcc_$x/log $dir_source_base/feature_mfcc_$x/scp_ark || exit 1;

  echo "===> execute steps/compute_cmvn_stats.sh <==="
  steps/compute_cmvn_stats.sh $dir_source_base/feature_mfcc_$x/train $dir_source_base/feature_mfcc_$x/log $dir_source_base/feature_mfcc_$x/scp_ark || exit 1;

  echo "===> execute utils/fix_data_dir.sh <==="
  utils/fix_data_dir.sh $dir_source_base/feature_mfcc_$x/train || exit 1;
done

# ---------------------------------------------------------

echo ""
echo "*********************************"
echo "***** MFCC Extraction Done. *****"
echo "*********************************"
