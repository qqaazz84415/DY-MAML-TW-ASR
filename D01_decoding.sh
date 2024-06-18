#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# test data
# dir_data_test=$dir_data_base/test_suisiann

# trained models
dir_ivector_extractor=$dir_source_feat_ivec/ivector_extractor
dir_gmm=$dir_target_gmm/lda_mllt
dir_gmm_hmm=$dir_target_gmm_hmm
dir_tdnn=$dir_target_tdnn/tdnn_chain_b
dir_tdnn_hmm=$dir_target_tdnn_hmm

# result
dt=$(date '+%Y-%m-%d_%H-%M-%S');
dir_result=$dir_result_base/result_${dt}
dir_feature=$dir_result/feature
dir_result_gmm_hmm=$dir_result/gmm_hmm
dir_result_tdnn_hmm=$dir_result/tdnn_hmm

mkdir -p $dir_result $dir_feature
cp -r $dir_data_test $dir_feature/test

# ---------------------------------------------------------
# <--- Parameter --->

decode_gmm_hmm=false
decode_tdnn_hmm=true

nj=8

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                            Feature Extraction                            ="
echo "============================================================================"

echo "===> execute utils/utt2spk_to_spk2utt.pl <==="
utils/utt2spk_to_spk2utt.pl $dir_feature/test/utt2spk > $dir_feature/test/spk2utt || exit 1;

echo "===> execute steps/make_mfcc.sh <==="
steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config conf/mfcc_hires.conf \
  $dir_feature/test $dir_feature/mfcc_log $dir_feature/mfcc_scp_ark || exit 1;

echo "===> execute steps/compute_cmvn_stats.sh <==="
steps/compute_cmvn_stats.sh $dir_feature/test $dir_feature/mfcc_log $dir_feature/mfcc_scp_ark || exit 1;

echo "===> execute utils/fix_data_dir.sh <==="
utils/fix_data_dir.sh $dir_feature/test || exit 1;

if [ "$decode_tdnn_hmm" == "true" ]; then
  echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
    $dir_feature/test $dir_ivector_extractor $dir_feature/ivector_scp_ark || exit 1;
fi


if [ "$decode_gmm_hmm" == "true" ]; then
  echo "============================================================================"
  echo "=                             Decoding GMM-HMM                             ="
  echo "============================================================================"

  mkdir -p $dir_result_gmm_hmm

  # Some checks (Note: we don't need $srcdir/tree but we expect it should exist, given the current structure of the scripts.)
  ln -s $dir_gmm/tree $dir_result_gmm_hmm/tree
  ln -s $dir_gmm/final.mdl $dir_result_gmm_hmm/final.mdl
  ln -s $dir_gmm/final.mat $dir_result_gmm_hmm/final.mat
  ln -s $dir_gmm/splice_opts $dir_result_gmm_hmm/splice_opts
  ln -s $dir_gmm/cmvn_opts $dir_result_gmm_hmm/cmvn_opts

  echo "===> execute steps/decode_fmllr.sh <==="
  steps/decode_fmllr.sh --nj $nj --cmd "$decode_cmd" $dir_gmm_hmm $dir_feature/test $dir_result_gmm_hmm/decode_result_wer || exit 1;
  grep WER $dir_result_gmm_hmm/decode_result_wer/wer_* | utils/best_wer.sh || exit 1;

  echo "===> execute steps/decode_fmllr_char.sh <==="
  steps/decode_fmllr_char.sh --nj $nj --cmd "$decode_cmd" $dir_gmm_hmm $dir_feature/test $dir_result_gmm_hmm/decode_result_cer || exit 1;
  grep WER $dir_result_gmm_hmm/decode_result_cer/cer_* | utils/best_wer.sh || exit 1;

  echo "===> execute steps/decode_fmllr_phone.sh <==="
  steps/decode_fmllr_phone.sh --nj $nj --cmd "$decode_cmd" $dir_gmm_hmm $dir_feature/test $dir_result_gmm_hmm/decode_result_per || exit 1;
  grep WER $dir_result_gmm_hmm/decode_result_per/per_* | utils/best_wer.sh || exit 1;
fi


if [ "$decode_tdnn_hmm" == "true" ]; then
  echo "============================================================================"
  echo "=                            Decoding TDNN-HMM                             ="
  echo "============================================================================"

  mkdir -p $dir_result_tdnn_hmm

  # Some checks
  ln -s $dir_tdnn/final.mdl $dir_result_tdnn_hmm/final.mdl
  ln -s $dir_tdnn/cmvn_opts $dir_result_tdnn_hmm/cmvn_opts
  ln -s $dir_tdnn/frame_subsampling_factor $dir_result_tdnn_hmm/frame_subsampling_factor
  # ln -s $dir_tdnn/log $dir_result_tdnn_hmm/log

  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  # rm $dir_tdnn/.error 2>/dev/null || true

  echo "===> execute steps/nnet3/decode.sh <==="
  steps/nnet3/decode.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --extra-left-context 0 --extra-right-context 0 \
    --extra-left-context-initial 0 \
    --extra-right-context-final 0 \
    --frames-per-chunk $frames_per_chunk \
    --nj $nj --cmd "$decode_cmd"  --num-threads 4 \
    --online-ivector-dir $dir_feature/ivector_scp_ark \
    $dir_tdnn_hmm $dir_feature/test $dir_result_tdnn_hmm/decode_result_wer || exit 1
    grep WER $dir_result_tdnn_hmm/decode_result_wer/wer_* | utils/best_wer.sh || exit 1;
  
  echo "===> execute steps/nnet3/decode_char.sh <==="
  steps/nnet3/decode_char.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --extra-left-context 0 --extra-right-context 0 \
    --extra-left-context-initial 0 \
    --extra-right-context-final 0 \
    --frames-per-chunk $frames_per_chunk \
    --nj $nj --cmd "$decode_cmd"  --num-threads 4 \
    --online-ivector-dir $dir_feature/ivector_scp_ark \
    $dir_tdnn_hmm $dir_feature/test $dir_result_tdnn_hmm/decode_result_cer || exit 1
    grep WER $dir_result_tdnn_hmm/decode_result_cer/cer_* | utils/best_wer.sh || exit 1;

  echo "===> execute steps/nnet3/decode_phone.sh <==="
  steps/nnet3/decode_phone.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --extra-left-context 0 --extra-right-context 0 \
    --extra-left-context-initial 0 \
    --extra-right-context-final 0 \
    --frames-per-chunk $frames_per_chunk \
    --nj $nj --cmd "$decode_cmd"  --num-threads 4 \
    --online-ivector-dir $dir_feature/ivector_scp_ark \
    $dir_tdnn_hmm $dir_feature/test $dir_result_tdnn_hmm/decode_result_per || exit 1
    grep WER $dir_result_tdnn_hmm/decode_result_per/per_* | utils/best_wer.sh || exit 1;
fi

# ---------------------------------------------------------

echo ""
echo "**************************"
echo "***** Decoding Done. *****"
echo "**************************"
