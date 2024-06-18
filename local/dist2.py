import argparse
from operator import le
import os
import numpy as np

parser = argparse.ArgumentParser(description='decide the proportion of each language')
parser.add_argument("logprobdir", help="directory of logprob")
parser.add_argument("IQdir", help="directory of IQ")
parser.add_argument("lastdistdir", help="load last dist from file")
parser.add_argument('round', help="current round of meta-learning")
args = parser.parse_args()

logprobpath = args.logprobdir
IQpath = args.IQdir
lastdistpath = args.lastdistdir
round = args.round
initial = 2000
total = 10000

# def softmax(x):
#     return np.exp(x) / np.sum(np.exp(x), axis=0)

def thresholdProb(logprob, dist, iq, alpha, beta, gamma):
    global total
    threshold = 1200.0/float(total)
    differ = 0.0
    lparray = np.array(logprob)
    print("lp: ", end='')
    print(lparray)
    lparray -= -10.0
    normlp = lparray / 10.0
    print("normlp: ", end='')
    print(normlp)
    darray = np.array(dist)
    iqarray = np.array(iq)
    iqarray *= 10
    print("initial prob: ", end='')
    print(alpha * normlp + beta * darray + gamma * iqarray)
    prob = alpha * normlp + beta * darray + gamma * iqarray
    # prob = normlp * darray * iqarray
    prob = prob/np.sum(prob)
    aboveThreshold = np.ones(len(prob), dtype=bool)
    allp = 0.0
    for i in range(0, len(prob)): # check if any element is lower than the threshold
        if(prob[i] < threshold): # if true, add the differ between its value and threshold
            differ += threshold - prob[i]
            prob[i] = threshold  # set the value to threshold
            aboveThreshold[i] = False # set the bool value of "above threshold" to False
        else:
            allp += prob[i] # if above the threshold, add the value to allp
    result = np.zeros(len(prob), dtype=float)
    for i in range(0, len(prob)):
        if(aboveThreshold[i]):
            result[i] =prob[i] - differ * (float(prob[i]) / float(allp))
        else:
            result[i] = prob[i]
    print("final prob:", end='')
    print(result)
    return result

def main():
    langs = ['ca', 'en', 'jp', 'md', 'th']
    logproblist = []
    IQlist = []
    p = 0.5
    alpha = 0.2
    beta = 0.1
    gamma = 0.7
    if(os.path.exists(lastdistpath + "/dist.txt")):
        for lang in langs:
            print("calculating distribution for " + lang)
            # logprob
            logprobtmps = []
            logprobtmpq = []
            logprobsupport = open(logprobpath + "/logprob_train_" + lang + "_" + round + "_support.txt", "r")
            logprobquery = open(logprobpath + "/logprob_train_" + lang + "_" + round + "_query.txt", "r")
            for line in logprobsupport:
                if len(line.split())!=1:
                    logprobtmps.append([float(i) for i in line.split()]) # six items in the list
            for line in logprobquery:
                if len(line.split())!=1:
                    logprobtmpq.append([float(i) for i in line.split()]) # six items in the list
            lpdiffSup = (logprobtmps[2][0] + logprobtmps[5][0]) / 2 + (logprobtmps[2][1] + logprobtmps[5][1]) / 2
            lpdiffQue = (logprobtmpq[2][0] + logprobtmpq[5][0]) / 2 + (logprobtmpq[2][1] + logprobtmpq[5][1]) / 2
            logproblist.append((1-p)*lpdiffSup + p*lpdiffQue)
            # IQ
            IQavg = 0.0
            count = 0
            IQfile = open(IQpath + "/train_" + lang + "/IQ.txt")
            next(IQfile)
            for line in IQfile:
                IQavg += float(line.split()[1])*float(line.split()[2])*float(line.split()[3])
                count += 1
            IQavg /= float(count)
            IQlist.append(IQavg)
        lastdistfile = open(lastdistpath + "/dist.txt", "r")
        next(lastdistfile)
        distlist = (lastdistfile.readline()).split()
        distlist = [float(i)/float(total) for i in distlist]
        print("lobProb: ", end='')
        print(logproblist)
        print("distribution: ", end='')
        print(distlist)
        print("IQ: ", end='')
        print(IQlist)
        newdist = thresholdProb(logproblist, distlist, IQlist, alpha, beta, gamma)
        lastdistfile.close()
        thisdistfile = open(lastdistpath + "/dist.txt", "w")
        thisdistfile.write("ca en jp md th\n")
        thisdistfile.write(str(int(np.rint(newdist[0]*total))) + " " + str(int(np.rint(newdist[1]*total))) + " " + str(int(np.rint(newdist[2]*total))) + " " + str(int(np.rint(newdist[3]*total))) + " " + str(int(np.rint(newdist[4]*total))))
    else:
        print("===> First round, creating initial distribution <===")
        thisdistfile = open(lastdistpath + "/dist.txt", "w")
        thisdistfile.write("ca en jp md th\n")
        thisdistfile.write(str(initial) + " " + str(initial) + " " + str(initial) + " " + str(initial) + " " + str(initial))

if __name__ == "__main__":
    main()