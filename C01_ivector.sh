#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh
# ./B01_mfcc.sh || exit 1;

# ---------------------------------------------------------
# <--- Directory --->

dir_mfcc=$dir_source_feat_mfcc
dir_ivec=$dir_source_feat_ivec

rm -rf $dir_ivec
mkdir -p $dir_ivec

# ---------------------------------------------------------
# <--- Parameter --->

stage=2  # assign the start stage

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                           i-Vector Extraction                            ="
echo "============================================================================"

if [ $stage -le 1 ]; then
  echo "-------------------- [stage 1: MFCC] --------------------"
  ./B01_mfcc.sh || exit 1;
fi

cp -r $dir_mfcc/train $dir_ivec/train

if [ $stage -le 2 ]; then
  echo "-------------------- [stage 2: PCA & UBM] --------------------"

  # Computing a subset of data to train the diagonal UBM.
  num_utt_total=$(wc -l <$dir_ivec/train/utt2spk)
  num_utt_sub=$[$num_utt_total/4]  # using a subset of about a quarter of the data

  echo "===> execute utils/data/subset_data_dir.sh <==="
  utils/data/subset_data_dir.sh $dir_ivec/train $num_utt_sub $dir_ivec/train_subset

  # Computing a PCA transform from the hires data.
  echo "===> execute steps/online/nnet2/get_pca_transform.sh <==="
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --max-utts 10000 --subsample 2 \
    $dir_ivec/train_subset \
    $dir_ivec/pca_transform

  # Training the diagonal UBM (Use 512 Gaussians in the UBM).
  echo "===> execute steps/online/nnet2/train_diag_ubm.sh <==="
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj $nj \
    --num-frames 700000 \
    --num-threads 32 \
    $dir_ivec/train_subset 512 \
    $dir_ivec/pca_transform $dir_ivec/diag_ubm
fi

if [ $stage -le 3 ]; then
  echo "-------------------- [stage 3: i-Vector - training] --------------------"

  echo "===> execute steps/online/nnet2/train_ivector_extractor.sh <==="
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj $nj \
    $dir_ivec/train $dir_ivec/diag_ubm $dir_ivec/ivector_extractor || exit 1;
fi

if [ $stage -le 4 ]; then
  echo "-------------------- [stage 4: i-Vector - extraction] --------------------"

  echo "===> execute utils/data/modify_speaker_info.sh <==="
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    $dir_ivec/train $dir_ivec/train_modify_speaker

  echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    $dir_ivec/train_modify_speaker $dir_ivec/ivector_extractor $dir_ivec/scp_ark
fi

# ---------------------------------------------------------

echo ""
echo "*************************************"
echo "***** i-Vector Extraction Done. *****"
echo "*************************************"
