#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

# corpus_list=(chitchat_text.txt number_text.txt life_text.txt tcc300_2076_text.txt msa_text.txt elderly_care.txt tainan_food.txt health.txt matbn_text.txt matbn-new_text.txt King-ASR-360_text.txt QA_text.txt King-ASR-044_text.txt ptt1_text.txt GigaWord_text.txt)
# weight_list=(2000 500 1500 500 500 1000 600 200 10 10 3 3 1 0.3 0.2)
# corpus_list=(chitchat_text.txt number_text.txt life_text.txt)
# weight_list=(2000 500 1500)
corpus_list=(chitchat_text.txt number_text.txt life_text.txt tcc300_2076_text.txt msa_text.txt elderly_care.txt tainan_food.txt health.txt matbn_text.txt matbn-new_text.txt QA_text.txt ptt1_text.txt GigaWord_text.txt corpus_dialog.txt)
weight_list=(2000 500 1500 500 500 1000 600 200 10 10 3 0.3 15 3)
num_corpus=${#corpus_list[@]}

corpus_dir=/media/hd03/shuuennokage_data/kaldi/egs/a_20190711_simple/data/lm_cs

dir_lang=$dir_source_lang
dir_ngram=$dir_source_ngram
dir_lm=$dir_target_lm

file_vocab=$file_data_vocab
file_text=$file_data_text

rm -rf $dir_ngram $dir_lm
mkdir -p $dir_ngram
cp -r $dir_lang $dir_lm  # "utils/mkgraph.sh" require lang data, L.fst and G.fst

# ---------------------------------------------------------
# <--- Parameter --->

ng=3  # n-gram

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                            N-gram Computation                            ="
echo "============================================================================"

for corpus_index in `seq 0 $[$num_corpus-1]`;do
  corpus_name=${corpus_list[$corpus_index]}
  corpus_weight=${weight_list[$corpus_index]}

  echo "===> execute ngram-count (.count) for ${corpus_name} <==="
  ngram-count \
    -order $ng \
    -vocab $file_vocab \
    -text $corpus_dir/${corpus_name} \
    -write $dir_ngram/${corpus_name}_${ng}-gram.count

  echo "===> execute local/ngram_count_weight.py for ${corpus_name} <==="
  python3 local/ngram_count_weight.py $dir_ngram/${corpus_name}_${ng}-gram.count $corpus_weight
done

echo "===> execute local/ngram_merge.py <==="
touch $dir_ngram/corpus_${ng}-gram.count
python3 local/ngram_merge.py $dir_ngram/corpus_${ng}-gram.count

echo "===> execute ngram-count (.arpa) <==="
ngram-count \
  -order $ng \
  -read $dir_ngram/corpus_${ng}-gram.count \
  -vocab $file_vocab \
  -lm $dir_ngram/corpus_${ng}-gram.arpa

echo "============================================================================"
echo "=                         Training Language Model                          ="
echo "============================================================================"

echo "===> execute utils/find_arpa_oovs.pl <==="
cat $dir_ngram/corpus_${ng}-gram.arpa | \
  utils/find_arpa_oovs.pl $dir_lm/words.txt  > $dir_ngram/oovs.txt

echo "===> language model WFST <==="
# grep -v '<s> <s>' because the LM seems to have some strange and useless
# stuff in it with multiple <s>'s in the history.  Encountered some other similar
# things in a LM from Geoff.  Removing all "illegal" combinations of <s> and </s>,
# which are supposed to occur only at being/end of utt.  These can cause
# determinization failures of CLG [ends up being epsilon cycles].
cat $dir_ngram/corpus_${ng}-gram.arpa | \
  grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
  arpa2fst - | fstprint | \
  utils/remove_oovs.pl $dir_ngram/oovs.txt | \
  utils/eps2disambig.pl | utils/s2eps.pl | \
  fstcompile \
    --isymbols=$dir_lm/words.txt \
    --osymbols=$dir_lm/words.txt  \
    --keep_isymbols=false --keep_osymbols=false | \
  fstrmepsilon | fstarcsort --sort_type=ilabel > $dir_lm/G.fst

# ---------------------------------------------------------

echo ""
echo "***************************************"
echo "***** N-gram Language Model Done. *****"
echo "***************************************"
