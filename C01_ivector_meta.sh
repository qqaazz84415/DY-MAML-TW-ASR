#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh
# ./B01_mfcc.sh || exit 1;

# ---------------------------------------------------------
# <--- Directory --->

dir_mfcc_ca=$dir_source_base/feature_mfcc_ca
dir_mfcc_jp=$dir_source_base/feature_mfcc_jp
dir_mfcc_th=$dir_source_base/feature_mfcc_th
dir_mfcc_en=$dir_source_base/feature_mfcc_en
dir_mfcc_md=$dir_source_base/feature_mfcc_md
dir_ivec_ca=$dir_source_base/feature_ivector_ca
dir_ivec_jp=$dir_source_base/feature_ivector_jp
dir_ivec_th=$dir_source_base/feature_ivector_th
dir_ivec_en=$dir_source_base/feature_ivector_en
dir_ivec_md=$dir_source_base/feature_ivector_md

# rm -rf $dir_ivec_ca $dir_ivec_jp $dir_ivec_th $dir_ivec_en $dir_ivec_md
# mkdir -p $dir_ivec_ca $dir_ivec_jp $dir_ivec_th $dir_ivec_en $dir_ivec_md
rm -rf $dir_ivec_en
mkdir $dir_ivec_en
# cp -r $dir_mfcc_ca/train $dir_ivec_ca/train
# cp -r $dir_mfcc_jp/train $dir_ivec_jp/train
# cp -r $dir_mfcc_th/train $dir_ivec_th/train
cp -rf $dir_mfcc_en/train $dir_ivec_en/train
# cp -r $dir_mfcc_md/train $dir_ivec_md/train

# ---------------------------------------------------------
# <--- Parameter --->

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                           i-Vector Extraction                            ="
echo "============================================================================"

for x in en
do
  echo "-------------------- [stage 1: PCA & UBM] --------------------"
  # Computing a subset of data to train the diagonal UBM.
  num_utt_total=$(wc -l <$dir_source_base/feature_ivector_$x/train/utt2spk)
  num_utt_sub=$[$num_utt_total/4]  # using a subset of about a quarter of the data

  echo "===> execute utils/data/subset_data_dir.sh <==="
  utils/data/subset_data_dir.sh $dir_source_base/feature_ivector_$x/train $num_utt_sub $dir_source_base/feature_ivector_$x/train_subset

  # Computing a PCA transform from the hires data.
  echo "===> execute steps/online/nnet2/get_pca_transform.sh <==="
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --max-utts 10000 --subsample 2 \
    $dir_source_base/feature_ivector_$x/train_subset \
    $dir_source_base/feature_ivector_$x/pca_transform

  # Training the diagonal UBM (Use 512 Gaussians in the UBM).
  echo "===> execute steps/online/nnet2/train_diag_ubm.sh <==="
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj $nj \
    --num-frames 700000 \
    --num-threads 32 \
    $dir_source_base/feature_ivector_$x/train_subset 512 \
    $dir_source_base/feature_ivector_$x/pca_transform $dir_source_base/feature_ivector_$x/diag_ubm

  echo "-------------------- [stage 2: i-Vector - training] --------------------"=
  echo "===> execute steps/online/nnet2/train_ivector_extractor.sh <==="
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj $nj \
    $dir_source_base/feature_ivector_$x/train $dir_source_base/feature_ivector_$x/diag_ubm $dir_source_base/feature_ivector_$x/ivector_extractor || exit 1;

  echo "-------------------- [stage 3: i-Vector - extraction] --------------------"
  echo "===> execute utils/data/modify_speaker_info.sh <==="
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    $dir_source_base/feature_ivector_$x/train $dir_source_base/feature_ivector_$x/train_modify_speaker

  echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    $dir_source_base/feature_ivector_$x/train_modify_speaker $dir_source_base/feature_ivector_$x/ivector_extractor $dir_source_base/feature_ivector_$x/scp_ark
done
# ---------------------------------------------------------

echo ""
echo "*************************************"
echo "***** i-Vector Extraction Done. *****"
echo "*************************************"
