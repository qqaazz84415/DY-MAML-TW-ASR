#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_lm=$dir_target_lm
dir_am=$dir_target_tdnn/tree
dir_graph=$dir_target_base/graph_tdnn_hmm_meta

rm -rf $dir_graph

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                              HCLG Creation                               ="
echo "============================================================================"

echo "===> execute utils/mkgraph.sh <==="
utils/mkgraph.sh --self-loop-scale 1.0 $dir_lm $dir_am $dir_graph || exit 1;

# ---------------------------------------------------------

echo ""
echo "********************************"
echo "***** TDNN-HMM Model Done. *****"
echo "********************************"
