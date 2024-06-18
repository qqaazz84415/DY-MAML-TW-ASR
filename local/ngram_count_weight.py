
import sys
import argparse
import math

# 進度條
def progress(count, total, suffix=''):
    bar_len = 60
    filled_len = int(round(bar_len * count / float(total)))
    percents = round(100.0 * count / float(total), 1)
    bar = '=' * filled_len + '-' * (bar_len - filled_len)
    sys.stdout.write('[%s] %s%s ...%s\r' % (bar, percents, '%', suffix))
    sys.stdout.flush()  # As suggested by Rom Ruben

def main():
    # ------------------------------ [初始化] ------------------------------
    parser = argparse.ArgumentParser(description='Setting weight to .count file')
    parser.add_argument('count', help="Path to .count file")
    parser.add_argument('weight', help="Weight")
    args = parser.parse_args()

    file_count = args.count  # .count檔案位置
    weight = args.weight  # 權重

    list_content = []

    # ------------------------------ [讀取&統計] ------------------------------
    with open(file_count, 'r', encoding='utf8') as f:
        lines = f.readlines()
        total = len(lines)
        for i, line in enumerate(lines):
            ngram, count = line[:-1].split('\t')  # [:-1]為去掉換行符
            list_content.append(ngram+'\t'+str(float(count)*float(weight)))
            # list_content.append(ngram+'\t'+str(math.ceil(float(count)*float(weight))))
            progress(i, total, suffix='Count')  #進度條

    # ------------------------------ [輸出] ------------------------------
    with open(file_count, 'w', encoding='utf8') as f:
        f.write('\n'.join(list_content)+'\n')

    print('[ALL Done]')

if __name__ == "__main__":
    main()
