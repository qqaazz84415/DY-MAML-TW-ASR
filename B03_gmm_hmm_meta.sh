#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_lm_ca=$dir_target_base/lm_ca
dir_lm_jp=$dir_target_base/lm_jp
dir_lm_th=$dir_target_base/lm_th
dir_lm_en=$dir_target_base/lm_en
dir_lm_md=$dir_target_base/lm_md
dir_am_ca=$dir_target_base/am_gmm_ca/lda_mllt
dir_am_jp=$dir_target_base/am_gmm_jp/lda_mllt
dir_am_th=$dir_target_base/am_gmm_th/lda_mllt
dir_am_en=$dir_target_base/am_gmm_en/lda_mllt
dir_am_md=$dir_target_base/am_gmm_md/lda_mllt
dir_graph_ca=$dir_target_base/graph_gmm_hmm_ca
dir_graph_jp=$dir_target_base/graph_gmm_hmm_jp
dir_graph_th=$dir_target_base/graph_gmm_hmm_th
dir_graph_en=$dir_target_base/graph_gmm_hmm_en
dir_graph_md=$dir_target_base/graph_gmm_hmm_md

# rm -rf $dir_graph_ca $dir_graph_jp $dir_graph_th $dir_graph_en $dir_graph_md
rm -rf $dir_graph_en

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                              HCLG Creation                               ="
echo "============================================================================"

for x in en
do
  echo "===> execute utils/mkgraph.sh <==="
  utils/mkgraph.sh $dir_target_base/lm_${x} $dir_target_base/am_gmm_${x}/lda_mllt $dir_target_base/graph_gmm_hmm_${x} || exit 1;
done

# ---------------------------------------------------------

echo ""
echo "*******************************"
echo "***** GMM-HMM Model Done. *****"
echo "*******************************"
