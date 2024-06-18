# local資料夾
## 各檔案用途
* dist/dist2.py: 用以決定各語言的比例，不採用與我一樣的方法則可以忽略
* extractlogprob.py: 抽取各語言每回合訓練結束的log-prob，不採用與我一樣的方法則可以忽略
* getDuration.py: 使用utils/data/get_utt2dur.sh取得每個訓練資料的utt2dur之後，可以用這個py檔取得各訓練語料的時長(單位為小時)
* IQcalculation.py: 計算IQ的script，不採用與我一樣的方法則可以忽略
* ngram_count_weight.py/ngram_merge.py: 將中文與台語的ngram合併的script，由竣煌學長編寫，若沒有要用到結合的ngram lm可忽略
* phrase2phone.sh/phrase2word.py: 用來把decode出來的phrase轉成character(syllable)或是phone，這部分不用動，是用來計算CER/PER的，會被自行呼叫
* removeSIL.py: 用來移除轉錄中的SIL部分，避免相關error rate計算錯誤，應該也不用動，一樣會被自行呼叫
* 三個score: 計算WER、CER、PER的script，在decode時就會自己被調用，不需要動
* 三個sumTree: 就是sum-tree取樣結構，不採用與我一樣的方法則可以忽略