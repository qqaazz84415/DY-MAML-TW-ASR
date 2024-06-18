#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# result


# ---------------------------------------------------------
# <--- Parameter --->

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                              Text to phones                              ="
echo "============================================================================"

# for x in en
# do
#   cat $dir_data_base/train_$x/text |\
#     steps/nnet3/chain/e2e/text_to_phones.py $dir_source_base/lang_$x > $dir_data_base/train_$x/text2phone.txt
# done

cat $dir_data_base/test_formosa/text |\
  steps/nnet3/chain/e2e/text_to_phones.py $dir_source_base/lang > $dir_data_base/test_formosa/text2phone.txt

cat $dir_data_base/dir_test/TW0311_revise/text |\
  steps/nnet3/chain/e2e/text_to_phones.py $dir_source_base/lang > $dir_data_base/dir_test/TW0311_revise/text2phone.txt