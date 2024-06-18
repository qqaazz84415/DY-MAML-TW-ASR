import sys
import argparse
import numpy as np
from numpy.lib.utils import safe_eval

parser = argparse.ArgumentParser(description='Sample high IQ data from each language')
parser.add_argument('datanum', help="Amount of data to sample")
parser.add_argument('datadir', help="directory of data")
parser.add_argument('sampledir', help="directory of data that need to be sampled")
args = parser.parse_args()

num = int(args.datanum)
dir = args.datadir
sampdir = args.sampledir

minP = 0.01
minR = 0.5
leftWidth = 10

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
            for i in range(1, leftWidth+1):
                if((data_idx-i >= 0) and (self.sampled[data_idx-i]==0)): # search for the left(visited but not sampled data)
                    data_idx = data_idx-i
                    leaf_idx = data_idx+self.capacity-1
                    self.sampled[data_idx] = 1
                    print("changed to " + str(data_idx))
                    break
        else:
            self.sampled[data_idx] = 1
        return leaf_idx, self.tree[leaf_idx], self.data[data_idx]

    @property
    def total_p(self):
        return self.tree[0]  # the root

def main():
    IQfile = open(dir + "/IQ.txt", "r")
    # test = open(dir + "/test.txt", "w")
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
        IQlist = line.split()
        id = IQlist[0]
        cp = float(IQlist[1]) if float(IQlist[1])>0.0 else minP
        # rarity = float(IQlist[2]) if float(IQlist[2])>0.0 else minR
        # IQval = float(IQlist[3]) if float(IQlist[3])>0.0 else minP
        # tree.add(cp*rarity*IQval, id)
        tree.add(cp, id)
    print(tree.total_p)
    # start sampling data
    prioritySeg = float(tree.total_p)/float(num)
    for i in range(num):
        a, b = prioritySeg * i, prioritySeg * (i + 1)
        v = np.random.uniform(a, b)
        idx, p, data = tree.get_leaf(v)
        tl.append(data)
        # test.write(data + " " + str(float(p)/float(tree.total_p)) + "\n")
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