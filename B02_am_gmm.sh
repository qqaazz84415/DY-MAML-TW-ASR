#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_lang=$dir_source_lang
dir_feat=$dir_source_feat_mfcc/train
dir_gmm=$dir_target_gmm

rm -rf $dir_gmm
mkdir -p $dir_gmm

# ln -s $dir_lang $dir_gmm/lang

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                       Training GMM Acoustic Model                        ="
echo "============================================================================"

# ---------- [Training monophone] ----------
echo "===> execute steps/train_mono.sh <==="
steps/train_mono.sh --cmd "$train_cmd" --nj $nj --cmvn-opts "--norm-means=true --norm-vars=true" \
  $dir_feat $dir_lang $dir_gmm/monophone || exit 1;

echo "===> execute steps/align_si.sh <==="
steps/align_si.sh --cmd "$train_cmd" --nj $nj \
  $dir_feat $dir_lang $dir_gmm/monophone $dir_gmm/monophone_ali || exit 1;

# ---------- [Training triphone - 1] ----------
echo "===> execute steps/train_deltas.sh <==="
steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
  4000 80000 $dir_feat $dir_lang $dir_gmm/monophone_ali $dir_gmm/triphone1 || exit 1;
echo "===> execute steps/align_si.sh <==="

steps/align_si.sh --cmd "$train_cmd" --nj $nj \
  $dir_feat $dir_lang $dir_gmm/triphone1 $dir_gmm/triphone1_ali || exit 1;

# ---------- [Training triphone - 2] ----------
echo "===> execute steps/train_deltas.sh <==="
steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
  4000 80000 $dir_feat $dir_lang $dir_gmm/triphone1_ali $dir_gmm/triphone2 || exit 1;

echo "===> execute steps/align_si.sh <==="
steps/align_si.sh --cmd "$train_cmd" --nj $nj \
  $dir_feat $dir_lang $dir_gmm/triphone2 $dir_gmm/triphone2_ali || exit 1;

# ---------- [Training lda_mllt] ----------
echo "===> execute steps/train_lda_mllt.sh <==="
steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
  8000 80000 $dir_feat $dir_lang $dir_gmm/triphone2_ali $dir_gmm/lda_mllt || exit 1;

echo "===> execute steps/align_fmllr.sh <==="  # if apply SAT, may should change this to align_si.sh
steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
  $dir_feat $dir_lang $dir_gmm/lda_mllt $dir_gmm/lda_mllt_ali

# ---------- [Training lda_mllt_sat] ----------
# steps/align_si.sh  --nj $nj --cmd "$train_cmd" --use-graphs true $dir_feat $dir_lang $dir_gmm/m4 $dir_gmm/m4.ali  || exit 1;
# steps/train_sat.sh --cmd "$train_cmd" 8000 80000 $dir_feat $dir_lang $dir_gmm/m4.ali $dir_gmm/m5 || exit 1;
# steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" $dir_feat $dir_lang $dir_gmm/m5 $dir_gmm/m5.ali || exit 1;
# steps/train_sat.sh  --cmd "$train_cmd" 8000 160000 $dir_feat $dir_lang $dir_gmm/m5.ali $dir_gmm/m6 || exit 1;
# steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" $dir_feat $dir_lang $dir_gmm/m6 $dir_gmm/m6.ali || exit 1;

# ---------------------------------------------------------

echo ""
echo "************************************"
echo "***** GMM Acoustic Model Done. *****"
echo "************************************"
