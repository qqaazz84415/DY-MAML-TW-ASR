import sys
import argparse
import numpy as np
import random

parser = argparse.ArgumentParser(description='Sample IQ data from each language')
parser.add_argument('-c', '--common', action="store_true", help="Use common phone as the sampling standard")
parser.add_argument('-r', '--rare', action="store_true", help="Use phone rarity as the sampling standard")
parser.add_argument('-i', '--iq', action="store_true", help="Use IQ as the sampling standard")
parser.add_argument('-a', '--all', action="store_true", help="Use all property as the sampling standard")
parser.add_argument('distdir', help="directory of distribution")
parser.add_argument('lang', help="the current language")
parser.add_argument('datadir', help="directory of data")
parser.add_argument('sampledir', help="directory of data that need to be sampled")
args = parser.parse_args()

distdir = args.distdir
lang = args.lang
dir = args.datadir
sampdir = args.sampledir

minP = 0.01
minR = 0.5
width = 1

# refrence: https://github.com/MorvanZhou/Reinforcement-learning-with-tensorflow
class SumTree(object):
    data_pointer = 0

    def __init__(self, capacity):
        self.capacity = capacity
        self.tree = np.zeros(2 * capacity - 1)  # for all priority values
        self.data = np.zeros(capacity, dtype=object)  # for all transitions
        self.sampled = np.zeros(capacity, dtype=bool)  # check if sampled

    def add(self, p, data):
        tree_idx = self.data_pointer + self.capacity - 1
        self.data[self.data_pointer] = data  # update data_frame
        self.update(tree_idx, p)  # update tree_frame

        self.data_pointer += 1
        if self.data_pointer >= self.capacity:  # replace when exceed the capacity
            self.data_pointer = 0

    def update(self, tree_idx, p):
        change = p - self.tree[tree_idx]
        self.tree[tree_idx] = p
        # then propagate the change through tree
        while tree_idx != 0:    # this method is faster than the recursive loop in the reference code
            tree_idx = (tree_idx - 1) // 2
            self.tree[tree_idx] += change

    def get_leaf(self, v):
        parent_idx = 0
        global width
        while True:     # the while loop is faster than the method in the reference code
            cl_idx = 2 * parent_idx + 1         # this leaf's left and right kids
            cr_idx = cl_idx + 1
            if cl_idx >= len(self.tree):        # reach bottom, end search
                leaf_idx = parent_idx
                break
            else:       # downward search, always search for a higher priority node
                if v <= self.tree[cl_idx]:
                    parent_idx = cl_idx
                else:
                    v -= self.tree[cl_idx]
                    parent_idx = cr_idx
        
        data_idx = leaf_idx - self.capacity + 1
        if(self.sampled[data_idx]==1):
            while(True):
                left = data_idx-width if data_idx-width>=0 else 0
                right = data_idx+width if data_idx+width<self.capacity else self.capacity-1
                if((self.sampled[left]==0) and (self.sampled[right]==0)): # both
                    if(random.randint(1, 2)==1):
                        data_idx -= width
                    else:
                        data_idx += width
                    break
                elif(self.sampled[left]==0): # left
                    data_idx -= width
                    break
                elif(self.sampled[right]==0): # right
                    data_idx += width
                    break
                # none
                width += 1
            leaf_idx = data_idx+self.capacity-1
            self.sampled[data_idx] = 1
            # print("changed to " + str(data_idx))
            width = 1
        else:
            self.sampled[data_idx] = 1
        return leaf_idx, self.tree[leaf_idx], self.data[data_idx]

    @property
    def total_p(self):
        return self.tree[0]  # the root

def main():
    if(not(args.all or args.common or args.rare or args.iq)):
        parser.error('No action requested, add -c, -r, -i (multiple is OK) or -a')
    elif(args.all and (args.common or args.rare or args.iq)):
        parser.error('-a/--all is conflicted with -c, -r, and -i')
    IQfile = open(dir + "/IQ.txt", "r")
    result = open(dir + "/samplingResult.txt", "w")
    text = open(dir + "/text", "r")
    utt2spk = open(dir + "/utt2spk", "r")
    wav = open(dir + "/wav.scp", "r")
    sampText = open(sampdir + "/text", "w")
    sampUtt2spk = open(sampdir + "/utt2spk", "w")
    sampWav = open(sampdir + "/wav.scp", "w")
    count = len(open(dir + "/IQ.txt").readlines())
    tl = []
    tree = SumTree(count-1)
    next(IQfile)
    # build up the tree
    for line in IQfile:
        id = (line.split('\t'))[0]
        if(args.all):
            cpval = (line.split('\t'))[1]
            rareval = (line.split('\t'))[2]
            iqval = (line.split('\t'))[3]
            cp = float(cpval) if float(cpval)>0.0 else minP
            rarity = float(rareval) if float(rareval)>0.0 else minR
            iq = float(iqval) if float(iqval)>0.0 else minP
            tree.add(cp*rarity*iq, id)
        else:
            weight = 1.0
            if(args.common):
                cpval = (line.split('\t'))[1]
                cp = float(cpval) if float(cpval)>0.0 else minP
                weight *= cp
            if(args.rare):
                rareval = (line.split('\t'))[2]
                rarity = float(rareval) if float(rareval)>0.0 else minR
                weight *= rarity
            if(args.iq):
                iqval = (line.split('\t'))[3]
                iq = float(iqval) if float(iqval)>0.0 else minP
                weight *= iq
            tree.add(weight, id)

    print(tree.total_p)
    totalIQcp = 0.0
    # start sampling data
    distfile = open(distdir + "/dist.txt", "r")
    langlist = distfile.readline().split()
    distlist = [int(i) for i in distfile.readline().split()]
    index = langlist.index(lang)
    num = distlist[index]
    prioritySeg = float(tree.total_p)/float(num)
    for i in range(num):
        a, b = prioritySeg * i, prioritySeg * (i + 1)
        v = np.random.uniform(a, b)
        idx, p, data = tree.get_leaf(v)
        tl.append(data)
        totalIQcp += p
    result.write("Average IQ: " + str(tree.total_p/float(tree.capacity)) + " Sampled Average IQ: " + str(totalIQcp/float(num)) + "\n")
    s = set(tl)
    textlist = []
    uttlist = []
    wavlist = []
    for line in text:
        textlist.append(line)
    for line in utt2spk:
        uttlist.append(line)
    for line in wav:
        wavlist.append(line)
    
    for content in s:
        id = str(content)
        index = [i for i, s in enumerate(wavlist) if id in s]
        sampText.write(str(textlist[index[0]]))
        sampUtt2spk.write(str(uttlist[index[0]]))
        sampWav.write(str(wavlist[index[0]]))
    sampText.close()
    sampUtt2spk.close()
    sampWav.close()

if __name__ == "__main__":
    main()