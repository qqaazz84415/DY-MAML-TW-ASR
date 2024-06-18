#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_dict=$dir_data_dict
dir_lang=$dir_source_lang

rm -rf $dir_lang
mkdir -p $dir_lang

# ---------------------------------------------------------
# <--- Parameter --->

oov_word="<SPOKEN_NOISE>"

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                         Preparing Language Data                          ="
echo "============================================================================"

echo "===> execute utils/prepare_lang.sh <==="
utils/prepare_lang.sh $dir_dict $oov_word ${dir_lang}_temp $dir_lang || exit 1;
# "--position-dependent-phones false" will cancel position dependent (i.e., _B, _E, _S, _I)

echo "===> execute utils/validate_lang.pl <==="
utils/validate_lang.pl --skip-determinization-check $dir_lang || exit 1;

# ---------------------------------------------------------

echo ""
echo "*****************************************"
echo "***** Preparing Language Data Done. *****"
echo "*****************************************"
