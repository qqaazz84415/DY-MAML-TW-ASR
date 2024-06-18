#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# dir_lang_ca=$dir_source_base/lang_ca
# dir_lang_jp=$dir_source_base/lang_jp
# dir_lang_th=$dir_source_base/lang_th
# dir_feat_ca=$dir_source_base/feature_mfcc_ca/train
# dir_feat_jp=$dir_source_base/feature_mfcc_jp/train
# dir_feat_th=$dir_source_base/feature_mfcc_th/train
dir_gmm_ca=$dir_target_base/am_gmm_ca
dir_gmm_jp=$dir_target_base/am_gmm_jp
dir_gmm_th=$dir_target_base/am_gmm_th
dir_gmm_md=$dir_target_base/am_gmm_md
dir_gmm_en=$dir_target_base/am_gmm_en

# rm -rf $dir_gmm_ca $dir_gmm_jp $dir_gmm_th $dir_gmm_md $dir_gmm_en
# mkdir -p $dir_gmm_ca $dir_gmm_jp $dir_gmm_th $dir_gmm_md $dir_gmm_en
rm -rf $dir_gmm_en
mkdir $dir_gmm_en

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                       Training GMM Acoustic Model                        ="
echo "============================================================================"

for x in en
do
  [ "$x" = "ca" ] && echo "===> Cantonese <==="
  [ "$x" = "jp" ] && echo "===> Japanese <==="
  [ "$x" = "th" ] && echo "===> Thai <==="
  [ "$x" = "md" ] && echo "===> Mandarin <==="
  [ "$x" = "en" ] && echo "===> English <==="
  # ---------- [Training monophone] ----------
  echo "===> execute steps/train_mono.sh <==="
  steps/train_mono.sh --cmd "$train_cmd" --nj $nj --cmvn-opts "--norm-means=true --norm-vars=true" \
    $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/monophone || exit 1;

  echo "===> execute steps/align_si.sh <==="
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/monophone $dir_target_base/am_gmm_$x/monophone_ali || exit 1;

  # ---------- [Training triphone - 1] ----------
  echo "===> execute steps/train_deltas.sh <==="
  steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
    4000 80000 $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/monophone_ali $dir_target_base/am_gmm_$x/triphone1 || exit 1;

  echo "===> execute steps/align_si.sh <==="
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/triphone1 $dir_target_base/am_gmm_$x/triphone1_ali || exit 1;

  # ---------- [Training triphone - 2] ----------
  echo "===> execute steps/train_deltas.sh <==="
  steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
    4000 80000 $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/triphone1_ali $dir_target_base/am_gmm_$x/triphone2 || exit 1;

  echo "===> execute steps/align_si.sh <==="
  steps/align_si.sh --cmd "$train_cmd" --nj $nj \
    $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/triphone2 $dir_target_base/am_gmm_$x/triphone2_ali || exit 1;

  # ---------- [Training lda_mllt] ----------
  echo "===> execute steps/train_lda_mllt.sh <==="
  steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
    8000 80000 $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/triphone2_ali $dir_target_base/am_gmm_$x/lda_mllt || exit 1;

  echo "===> execute steps/align_fmllr.sh <==="  # if apply SAT, may should change this to align_si.sh
  steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
    $dir_source_base/feature_mfcc_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/lda_mllt $dir_target_base/am_gmm_$x/lda_mllt_ali
done

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
