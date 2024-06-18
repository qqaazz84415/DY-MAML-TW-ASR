#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh
# ./A02_lm_ngram.sh || exit 1;
# ./B02_am_gmm.sh || exit 1;

# ---------------------------------------------------------
# <--- Directory --->

dir_lm=$dir_target_lm
dir_am=$dir_target_gmm/lda_mllt
dir_graph=$dir_target_gmm_hmm

rm -rf $dir_graph

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                              HCLG Creation                               ="
echo "============================================================================"

echo "===> execute utils/mkgraph.sh <==="
utils/mkgraph.sh $dir_lm $dir_am $dir_graph || exit 1;

# ---------------------------------------------------------

echo ""
echo "*******************************"
echo "***** GMM-HMM Model Done. *****"
echo "*******************************"
