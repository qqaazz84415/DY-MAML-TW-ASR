import argparse
import math

parser = argparse.ArgumentParser(description='Calculate IQ from the data of each language')
parser.add_argument('gtdir', help="dir of ground truth data")
parser.add_argument('PPGdir', help="directory of PPG data")
parser.add_argument('IQdir', help="directory to save IQ")
parser.add_argument('nj', help="number of job")
args = parser.parse_args()

gtdir = args.gtdir
PPGdir = args.PPGdir
IQdir = args.IQdir
nj = int(args.nj)

def main():
    flag = 0
    phone = open(gtdir + "/phoneRange.txt", "r")
    plist = []
    duration = []
    for line in phone:
        plist.append(line.split()[0])
        duration.append(line.split()[1:])
    rare = open(gtdir + "/phoneRarity.txt", "r")
    rarelist = []
    frequencylist = []
    for line in rare:
        l = line.split("\t")
        rarelist.append(line.split("\t")[0])
        frequencylist.append(line.split("\t")[2])
    gtfile = open(gtdir + "/gt_mask.txt", "r")
    IQfile = open(IQdir + "/IQ.txt", "w")
    IQfile.write("Utterance\tCP Proportion\tFreq CP\tConfidence score\tConfidence original score\n")
    for i in range(1, nj+1):
        PPGfile = open(PPGdir + "/phone_post." + str(i) + ".ark", "r")
        ppglist = []
        for ppgline in PPGfile:
            ppgframe = ppgline.split()
            if('[' in ppgframe):
                id = ppgframe[0]
            elif(']' in ppgframe): # end of sentence, start to calculate
                ppgprob = [float(i) for i in ppgframe[:-1]]
                ppglist.append(ppgprob)
                count = 0
                IQval = 0.0
                IQorigin = 0.0
                frequency = 0.0
                for i in range(0, len(ppglist)):  # for all frame in a sentence
                    pos = 0 if i!=0 else 1
                    if(not flag):  # didn't have skipped sentence
                        gtlist = gtfile.readline().split()
                    else:         # if we have skipped sentence
                        flag = 0  # then skip reading a new sentence
                    if(i==0 and id!=gtlist[0]): # some sequence alignment are skipped
                        flag = 1
                        break # skip the ppg
                    if(gtlist[pos]!="<m>"): # if the phone is common phone
                        count = count + 1
                        index = plist.index(gtlist[pos])
                        prob = sum(ppgprob[int(duration[index][0]):int(duration[index][1])+1]) # add up the probability of all similiar phone
                        prob /= float(int(duration[index][1]) - int(duration[index][0]) + 1)
                        IQval = IQval - math.log2(1-prob) # calculate the IQ
                        IQorigin = IQorigin + prob
                        index = rarelist.index(gtlist[pos])
                        frequency = frequency + float(frequencylist[index]) # add up the frequency
                cpProp = float(count)/float(len(ppglist)) if not flag else 0.0
                # flag = skip sentence
                # count = common phones amount
                # flag = 1 => skip sentence, count = 0
                # flag = 0 => no skip sentence 
                frequency = float(frequency) / float(count) if count!=0 else 0.0
                IQval = float(frequency) / float(count)  if count!=0 else 0.0
                IQorigin = float(IQorigin) / float(count) if count!=0 else 0.0
                IQfile.write(id + "\t" + str(cpProp) + "\t" + str(frequency) + "\t" + str(IQval) + "\t" + str(IQorigin) + "\n")
                ppglist.clear()
            else:
                ppgprob = [float(i) for i in ppgframe]
                ppglist.append(ppgprob)
    
if __name__ == "__main__":
    main()