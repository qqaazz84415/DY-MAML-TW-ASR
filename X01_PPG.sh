#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# trained models
dir_ivector_extractor=$dir_source_feat_ivec/ivector_extractor
dir_gmm=$dir_target_gmm/lda_mllt
dir_gmm_hmm=$dir_target_gmm_hmm
dir_tdnn=$dir_target_tdnn/tdnn_chain
dir_tdnn_hmm=$dir_target_tdnn_hmm

# result
#dt=$(date '+%Y-%m-%d_%H-%M-%S');
#dir_result=$dir_result_base/result_${dt}
ppg=nBest
# dir_feature=$ppg/feature
# dir_result_tdnn_ppg=$pgg/ppg

# ---------------------------------------------------------
# <--- Parameter --->

nj=16

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                            Feature Extraction                            ="
echo "============================================================================"

for x in jp
do
  rm -rf $ppg/train_$x
  mkdir -p $ppg/train_$x/feature $ppg/train_$x/ppg
  cp -r $dir_source_base/feature_mfcc_$x/train $ppg/train_$x/feature/train
  cp -r $dir_source_base/feature_mfcc_$x/scp_ark $ppg/train_$x/feature/mfcc_scp_ark

  echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    $ppg/train_$x/feature/train $dir_ivector_extractor $ppg/train_$x/feature/ivector_scp_ark || exit 1;
  
  echo "===> execute steps/nnet3/chain/get_phone_post.sh <==="
  steps/nnet3/chain/get_phone_post.sh --nj $nj \
    --online-ivector-dir $ppg/train_$x/feature/ivector_scp_ark \
    $dir_target_tdnn/tree $dir_target_tdnn/tdnn_chain $dir_target_lm \
    $ppg/train_$x/feature/train $ppg/train_$x/ppg || exit 1;
done