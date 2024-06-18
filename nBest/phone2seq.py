import sys

nbest = open(str(sys.argv[1]+"/nbest_prob.txt") , "r")
seq = open(str(sys.argv[1]+"/seq.txt") , "w")

line = nbest.readline()
last = ""
flag = 0
while line:
    l = line.split()
    if len(str(l[0]))>8:
        if flag==0:
            flag = 1
        else:
            seq.write("\n")
        seq.write(l[0] + " ")
    elif l[0]=="<eps>":
        line = nbest.readline()
        continue
    elif l[0]!=last:
        seq.write(l[0] + " ")
        last = l[0]
    
    line = nbest.readline()