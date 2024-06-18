#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh
# ./A01_lang.sh || exit 1;

# ---------------------------------------------------------
# <--- Directory --->

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

echo "===> execute ngram-count (.count) <==="
ngram-count \
  -order $ng \
  -vocab $file_vocab \
  -text $file_text \
  -write $dir_ngram/corpus_${ng}-gram.count

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
