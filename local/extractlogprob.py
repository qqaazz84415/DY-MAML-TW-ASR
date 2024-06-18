import sys
import argparse

parser = argparse.ArgumentParser(description="Extract logProb from training log and validating log")
parser.add_argument('logpath', help="path to the log files")
parser.add_argument('langtag', help="language of the training round")
parser.add_argument('round', help="the round of current meta-learning")
parser.add_argument('metastep', help="tag of support set or query set")
parser.add_argument('outdir', help="output directory of the file")

args = parser.parse_args()

logpath = args.logpath
langtag = args.langtag
r = args.round
metastep = args.metastep
outdir = args.outdir

def main():
    logprob_out = open(outdir + "/logprob_train_" + str(langtag) + "_" + str(r) + "_" + str(metastep) + ".txt", "w")
    trainlist = []
    validlist = []
    for i in range(0, 3):
        logprob_train = open(logpath + "/compute_prob_train." + str(i) + ".log", "r")
        logprob_valid = open(logpath + "/compute_prob_valid." + str(i) + ".log", "r")
        for line in logprob_train:
            if("log-probability" in line):
                if("=" in line):
                    index = (line.split()).index("=")
                else:
                    index = (line.split()).index("is")
                trainlist.append((line.split())[index+1])
        for line in logprob_valid:
            if("log-probability" in line):
                if("=" in line):
                    index = (line.split()).index("=")
                else:
                    index = (line.split()).index("is")
                validlist.append((line.split())[index+1])
                
    logprob_out.write("train:\n")
    for i in range(0, len(trainlist)):
        logprob_out.write(trainlist[i])
        logprob_out.write(" " if i%2==0 else "\n")
    logprob_out.write("valid:\n")
    for i in range(0, len(validlist)):
        logprob_out.write(validlist[i])
        logprob_out.write(" " if i%2==0 else "\n")

if __name__ == "__main__":
    main()