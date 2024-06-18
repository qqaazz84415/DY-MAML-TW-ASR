import sys
import argparse

parser = argparse.ArgumentParser(description='Change phrases into words')
parser.add_argument('dir', help="Path of the files to change")
parser.add_argument('minlmwt', help="minLMWeight")
parser.add_argument('maxlmwt', help="maxLMWeight")
parser.add_argument('wip', help="the current word ins penalty")
args = parser.parse_args()

dir = args.dir
minLmWeight = args.minlmwt
maxLmWeight = args.maxlmwt
wip = args.wip

print("===> Changing phrase into words for penalty " + wip + " <===")
for i in range(int(minLmWeight), int(maxLmWeight)+1):
    input = open(dir + "/scoring_kaldi/penalty_" + str(wip) + "/" + str(i) + ".txt", "r")
    output = open(dir + "/scoring_kaldi/penalty_" + str(wip) + "/" + str(i) + "_w.txt", "w")
    for line in input:
        seqlist = line.split(' ', 1)
        id = seqlist[0]
        p2w = seqlist[1].replace("-", " ")
        output.write(id + " " + p2w)
filt = open(dir + "/scoring_kaldi/test_filt.txt", "r")
filt_out = open(dir + "/scoring_kaldi/test_filt_w.txt", "w")
for line in filt:
    seqlist = line.split(' ', 1)
    id = seqlist[0]
    p2w = seqlist[1].replace("-", " ")
    filt_out.write(id + " " + p2w)