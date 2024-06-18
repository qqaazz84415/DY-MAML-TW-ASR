#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_dict_ca=$dir_data_base/dict_ca
dir_dict_th=$dir_data_base/dict_th
dir_dict_jp=$dir_data_base/dict_jp
dir_lang_ca=$dir_source_base/lang_ca
dir_lang_th=$dir_source_base/lang_th
dir_lang_jp=$dir_source_base/lang_jp

# rm -rf $dir_lang_ca $dir_lang_jp $dir_lang_th
# mkdir -p $dir_lang_ca $dir_lang_jp $dir_lang_th

# ---------------------------------------------------------
# <--- Parameter --->

oov_word="<SPOKEN_NOISE>"

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                         Preparing Language Data                          ="
echo "============================================================================"

# echo "===> processing Cantonese data <==="
# echo "===> execute utils/prepare_lang.sh <==="
# utils/prepare_lang.sh $dir_dict_ca $oov_word ${dir_lang_ca}_temp $dir_lang_ca || exit 1;
# # "--position-dependent-phones false" will cancel position dependent (i.e., _B, _E, _S, _I)

# echo "===> execute utils/validate_lang.pl <==="
# utils/validate_lang.pl --skip-determinization-check $dir_lang_ca || exit 1;

echo "===> processing Thai data <==="
echo "===> execute utils/prepare_lang.sh <==="
utils/prepare_lang.sh $dir_dict_th $oov_word ${dir_lang_th}_temp $dir_lang_th || exit 1;
# "--position-dependent-phones false" will cancel position dependent (i.e., _B, _E, _S, _I)

echo "===> execute utils/validate_lang.pl <==="
utils/validate_lang.pl --skip-determinization-check $dir_lang_th || exit 1;

# echo "===> processing Japanese data <==="
# echo "===> execute utils/prepare_lang.sh <==="
# utils/prepare_lang.sh $dir_dict_jp $oov_word ${dir_lang_jp}_temp $dir_lang_jp || exit 1;
# # "--position-dependent-phones false" will cancel position dependent (i.e., _B, _E, _S, _I)

# echo "===> execute utils/validate_lang.pl <==="
# utils/validate_lang.pl --skip-determinization-check $dir_lang_jp || exit 1;

# ---------------------------------------------------------

echo ""
echo "*****************************************"
echo "***** Preparing Language Data Done. *****"
echo "*****************************************"
