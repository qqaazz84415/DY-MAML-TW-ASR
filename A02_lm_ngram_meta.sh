#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh
# ./A01_lang.sh || exit 1;

# ---------------------------------------------------------
# <--- Directory --->

dir_lang_ca=$dir_source_base/lang_ca
dir_ngram_ca=$dir_source_base/ngram_ca
dir_lm_ca=$dir_target_base/lm_ca
dir_lang_th=$dir_source_base/lang_th
dir_ngram_th=$dir_source_base/ngram_th
dir_lm_th=$dir_target_base/lm_th
dir_lang_jp=$dir_source_base/lang_jp
dir_ngram_jp=$dir_source_base/ngram_jp
dir_lm_jp=$dir_target_base/lm_jp

file_vocab_ca=$dir_data_base/lm_ca/cantonese.vocab
file_text_ca=$dir_data_base/lm_ca/cWiki.txt
file_vocab_th=$dir_data_base/lm_th/thai.vocab
file_text_th=$dir_data_base/lm_th/thaiCorpus.txt
file_vocab_jp=$dir_data_base/lm_jp/jp.vocab
file_text_jp=$dir_data_base/lm_jp/ja.wikipedia_250k.txt

rm -rf $dir_ngram_ca $dir_ngram_th $dir_ngram_jp $dir_lm_ca $dir_lm_th $dir_lm_jp
mkdir -p $dir_ngram_ca $dir_ngram_th $dir_ngram_jp
cp -r $dir_lang_ca $dir_lm_ca  # "utils/mkgraph.sh" require lang data, L.fst and G.fst
cp -r $dir_lang_th $dir_lm_th  # "utils/mkgraph.sh" require lang data, L.fst and G.fst
cp -r $dir_lang_jp $dir_lm_jp  # "utils/mkgraph.sh" require lang data, L.fst and G.fst

# ---------------------------------------------------------
# <--- Parameter --->

ng=3  # 3-gram

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                            N-gram Computation                            ="
echo "============================================================================"

echo "===> execute ngram-count (.count) for Cantonese <==="
ngram-count \
  -order $ng \
  -vocab $file_vocab_ca \
  -text $file_text_ca \
  -write $dir_ngram_ca/corpus_${ng}-gram.count

echo "===> execute ngram-count (.arpa) for Cantonese <==="
ngram-count \
  -order $ng \
  -read $dir_ngram_ca/corpus_${ng}-gram.count \
  -vocab $file_vocab_ca \
  -lm $dir_ngram_ca/corpus_${ng}-gram.arpa

echo "===> execute ngram-count (.count) for Japanese <==="
ngram-count \
  -order $ng \
  -vocab $file_vocab_jp \
  -text $file_text_jp \
  -write $dir_ngram_jp/corpus_${ng}-gram.count

echo "===> execute ngram-count (.arpa) for Japanese <==="
ngram-count \
  -order $ng \
  -read $dir_ngram_jp/corpus_${ng}-gram.count \
  -vocab $file_vocab_jp \
  -lm $dir_ngram_jp/corpus_${ng}-gram.arpa

echo "===> execute ngram-count (.count) for Thai <==="
ngram-count \
  -order $ng \
  -vocab $file_vocab_th \
  -text $file_text_th \
  -write $dir_ngram_th/corpus_${ng}-gram.count

echo "===> execute ngram-count (.arpa) for Thai <==="
ngram-count \
  -order $ng \
  -read $dir_ngram_th/corpus_${ng}-gram.count \
  -vocab $file_vocab_th \
  -lm $dir_ngram_th/corpus_${ng}-gram.arpa

echo "============================================================================"
echo "=                         Training Language Model                          ="
echo "============================================================================"

echo "===> execute utils/find_arpa_oovs.pl <==="
cat $dir_ngram_ca/corpus_${ng}-gram.arpa | \
  utils/find_arpa_oovs.pl $dir_lm_ca/words.txt  > $dir_ngram_ca/oovs.txt

echo "===> language model WFST <==="
# grep -v '<s> <s>' because the LM seems to have some strange and useless
# stuff in it with multiple <s>'s in the history.  Encountered some other similar
# things in a LM from Geoff.  Removing all "illegal" combinations of <s> and </s>,
# which are supposed to occur only at being/end of utt.  These can cause
# determinization failures of CLG [ends up being epsilon cycles].
cat $dir_ngram_ca/corpus_${ng}-gram.arpa | \
  grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
  arpa2fst - | fstprint | \
  utils/remove_oovs.pl $dir_ngram_ca/oovs.txt | \
  utils/eps2disambig.pl | utils/s2eps.pl | \
  fstcompile \
    --isymbols=$dir_lm_ca/words.txt \
    --osymbols=$dir_lm_ca/words.txt  \
    --keep_isymbols=false --keep_osymbols=false | \
  fstrmepsilon | fstarcsort --sort_type=ilabel > $dir_lm_ca/G.fst

echo "===> execute utils/find_arpa_oovs.pl <==="
cat $dir_ngram_jp/corpus_${ng}-gram.arpa | \
  utils/find_arpa_oovs.pl $dir_lm_jp/words.txt  > $dir_ngram_jp/oovs.txt

echo "===> language model WFST <==="
# grep -v '<s> <s>' because the LM seems to have some strange and useless
# stuff in it with multiple <s>'s in the history.  Encountered some other similar
# things in a LM from Geoff.  Removing all "illegal" combinations of <s> and </s>,
# which are supposed to occur only at being/end of utt.  These can cause
# determinization failures of CLG [ends up being epsilon cycles].
cat $dir_ngram_jp/corpus_${ng}-gram.arpa | \
  grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
  arpa2fst - | fstprint | \
  utils/remove_oovs.pl $dir_ngram_jp/oovs.txt | \
  utils/eps2disambig.pl | utils/s2eps.pl | \
  fstcompile \
    --isymbols=$dir_lm_jp/words.txt \
    --osymbols=$dir_lm_jp/words.txt  \
    --keep_isymbols=false --keep_osymbols=false | \
  fstrmepsilon | fstarcsort --sort_type=ilabel > $dir_lm_jp/G.fst

echo "===> execute utils/find_arpa_oovs.pl <==="
cat $dir_ngram_th/corpus_${ng}-gram.arpa | \
  utils/find_arpa_oovs.pl $dir_lm_th/words.txt  > $dir_ngram_th/oovs.txt

echo "===> language model WFST <==="
# grep -v '<s> <s>' because the LM seems to have some strange and useless
# stuff in it with multiple <s>'s in the history.  Encountered some other similar
# things in a LM from Geoff.  Removing all "illegal" combinations of <s> and </s>,
# which are supposed to occur only at being/end of utt.  These can cause
# determinization failures of CLG [ends up being epsilon cycles].
cat $dir_ngram_th/corpus_${ng}-gram.arpa | \
  grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
  arpa2fst - | fstprint | \
  utils/remove_oovs.pl $dir_ngram_th/oovs.txt | \
  utils/eps2disambig.pl | utils/s2eps.pl | \
  fstcompile \
    --isymbols=$dir_lm_th/words.txt \
    --osymbols=$dir_lm_th/words.txt  \
    --keep_isymbols=false --keep_osymbols=false | \
  fstrmepsilon | fstarcsort --sort_type=ilabel > $dir_lm_th/G.fst

# ---------------------------------------------------------

echo ""
echo "***************************************"
echo "***** N-gram Language Model Done. *****"
echo "***************************************"
