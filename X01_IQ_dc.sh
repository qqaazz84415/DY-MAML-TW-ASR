#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# trained models
dir_ivector_extractor=$dir_source_feat_ivec/ivector_extractor
dir_gmm=$dir_target_gmm/lda_mllt
dir_final=$dir_target_tdnn/tdnn_chain
dir_ppg=$dir_proj_base/nBest
dir_ali=$dir_proj_base/alignment
dir_log_prob=$dir_data_base/logprob2
dir_dist=$dir_data_base/distribution2

function usage()
{
  echo "==================================================================================="
  echo "= This script is for extracting the PPG of each language and get their IQ values. ="
  echo "= usage: ./X01_IQ.sh [-h] [-f] final_model                                        ="
  echo "==================================================================================="
}

# ---------------------------------------------------------
# <--- Parameter --->

nj=16
stage=2
round=0

# ---------------------------------------------------------
# <--- Execute Scripts --->

function pause(){
  read -p "$*"
}

while [[ $# -gt 0 ]] # parsing parameters
do
  key="$1"
  case $key in
    -f|--final)
      dir_final="$2"
      shift # past argument
      shift # past value
      ;;
    -r|--round)
      round="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      shift # past argument
      ;;
  esac
done

echo "============================================================================"
echo "=                              IQ calculation                              ="
echo "============================================================================"

echo "$0 $@"
echo "===> directory to the final.mdl is $dir_final <==="
echo "===> current round of meta-training is $round <==="

if [ $stage -le 1 ]; then
  echo "-------------------- [stage 1: PPG] --------------------"
  for x in ca en jp md th
  do
    echo "===================> Extracting PPG <==================="
    echo "==========> Copying files for PPG calculation <=========="
    rm -rf $dir_ppg/train_$x/feature $dir_ppg/train_$x/ppg
    mkdir -p $dir_ppg/train_$x/feature $dir_ppg/train_$x/ppg
    cp -r $dir_source_base/feature_mfcc_$x/train $dir_ppg/train_$x/feature/train
    cp -r $dir_source_base/feature_mfcc_$x/scp_ark $dir_ppg/train_$x/feature/mfcc_scp_ark

    echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
      $dir_ppg/train_$x/feature/train $dir_ivector_extractor $dir_ppg/train_$x/feature/ivector_scp_ark || exit 1;
    
    echo "===> execute steps/nnet3/chain/get_phone_post.sh <==="
    steps/nnet3/chain/get_phone_post.sh --nj $nj \
      --online-ivector-dir $dir_ppg/train_$x/feature/ivector_scp_ark \
      $dir_target_tdnn/tree $dir_final $dir_target_lm \
      $dir_ppg/train_$x/feature/train $dir_ppg/train_$x/ppg || exit 1;

    # pause 'Press [Enter] to continue...'
    
    echo "==========> Calculating IQ <=========="
    python3 local/IQcalculation.py $dir_ali/$x $dir_ppg/train_$x/ppg $dir_data_base/train_$x $nj

    echo "==========> Deleting data to save space <=========="
    rm -rf $dir_ppg/train_$x/feature $dir_ppg/train_$x/ppg
  done
fi

if [ $stage -le 2 ]; then
  echo "-------------------- [stage 2: Distribution] --------------------"
  python3 local/dist2.py $dir_log_prob $dir_data_base $dir_dist $round
fi