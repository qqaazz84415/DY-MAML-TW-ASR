
import sys
import argparse
import math

# progress bar
def progress(count, total, suffix=''):
    bar_len = 60
    filled_len = int(round(bar_len * count / float(total)))
    percents = round(100.0 * count / float(total), 1)
    bar = '=' * filled_len + '-' * (bar_len - filled_len)
    sys.stdout.write('[%s] %s%s ...%s\r' % (bar, percents, '%', suffix))
    sys.stdout.flush()  # As suggested by Rom Ruben

def main():
    # ------------------------------ [Initialization] ------------------------------
    parser = argparse.ArgumentParser(description='Setting weight to .count file')
    # parser.add_argument('src_count1', help="Path to .count file")
    # parser.add_argument('src_count2', help="Path to .count file"")
    parser.add_argument('tgt_count', help="Path to .count file")
    args = parser.parse_args()

    # path_src_count1 = args.src_count1
    # path_src_count2 = args.src_count2
    path_tgt_count = args.tgt_count

    SOURCE_DIR = '/media/hd03/shuuennokage_data/kaldi/egs/a_20190711_simple/source/ngram_tw'
    # LIST_SOURCE_COUNT = ['chitchat_text.txt_3-gram.count', 
    #     'number_text.txt_3-gram.count', 
    #     'life_text.txt_3-gram.count'
    # ]
    LIST_SOURCE_COUNT = ['chitchat_text.txt_3-gram.count', 
        'number_text.txt_3-gram.count', 
        'life_text.txt_3-gram.count', 
        'tcc300_2076_text.txt_3-gram.count', 
        'msa_text.txt_3-gram.count', 
        'elderly_care.txt_3-gram.count', 
        'tainan_food.txt_3-gram.count', 
        'health.txt_3-gram.count', 
        'matbn_text.txt_3-gram.count', 
        'matbn-new_text.txt_3-gram.count', 
        'QA_text.txt_3-gram.count', 
        'ptt1_text.txt_3-gram.count'
    ]

    list_content = []

    # ------------------------------ [Read&Count] ------------------------------
    dict_ngram_count = {}
    for j, source_count in enumerate(LIST_SOURCE_COUNT):
        with open(SOURCE_DIR + '/' + source_count, 'r', encoding='utf8') as f:
            lines = f.readlines()
            total = len(lines)
            for i, line in enumerate(lines):
                ngram, count = line[:-1].split('\t')  # [:-1] removes the newline char
                if ngram in dict_ngram_count.keys():
                    dict_ngram_count[ngram] += float(count)
                else:
                    dict_ngram_count[ngram] = float(count)
                progress(i, total, suffix='Merge')  #progress bar
        print(source_count)

    for ngram, count in dict_ngram_count.items():
        list_content.append(ngram+'\t'+str(count))

    # ------------------------------ [Output] ------------------------------
    with open(path_tgt_count, 'w', encoding='utf8') as f:
        f.write('\n'.join(list_content)+'\n')

    print('[ALL Done]')

if __name__ == "__main__":
    main()
