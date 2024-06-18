import argparse
import numpy as np

parser = argparse.ArgumentParser(description='decide the proportion of each language')
parser.add_argument('dir', help="Path of the files to change")
parser.add_argument('minlmwt', help="minLMWeight")
parser.add_argument('maxlmwt', help="maxLMWeight")
parser.add_argument('wip', help="the current word ins penalty")
args = parser.parse_args()

dir = args.dir
minLmWeight = args.minlmwt
maxLmWeight = args.maxlmwt
wip = args.wip

def main():
    print("===> removing SIL for penalty " + wip + " <===")
    for i in range(int(minLmWeight), int(maxLmWeight)+1):
        input = open(dir + "/scoring_kaldi/penalty_" + str(wip) + "/" + str(i) + "_p_tmp.txt", "r")
        output = open(dir + "/scoring_kaldi/penalty_" + str(wip) + "/" + str(i) + "_p.txt", "w")
        for line in input:
            seqlist = line.split(' ', 1)
            id = seqlist[0]
            output.write(str(id) + " ")
            seq = str(seqlist[1]).split()
            for element in seq:
                if (element != "SIL"):
                    output.write(str(element) + " ")
            output.write("\n")
    filt = open(dir + "/scoring_kaldi/test_filt_p_tmp.txt", "r")
    filt_out = open(dir + "/scoring_kaldi/test_filt_p.txt", "w")
    for line in filt:
        seqlist = line.split(' ', 1)
        id = seqlist[0]
        filt_out.write(str(id) + " ")
        seq = str(seqlist[1]).split()
        for element in seq:
            if (element != "SIL"):
                filt_out.write(str(element) + " ")
        filt_out.write("\n")

if __name__ == "__main__":
    main()