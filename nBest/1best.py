import sys

phone = open(str(sys.argv[1]+"/phones.txt"), "r")
nbest = open(str(sys.argv[1]+"/nbest_prob.txt") , "w")

plist = []

line = phone.readline()
while line:
    tmp = line.split()
    plist.append(tmp[0])
    line = phone.readline()

for i in range(1, 9):
    ppg = open(str(sys.argv[1]+"/phone_post." + str(i) + ".ark"), "r")
    line = ppg.readline()
    while line:
        tmp = line.split()
        if(']' in tmp):
            del tmp[-1]
        elif('[' in tmp):
            nbest.write(tmp[0]+"\n")
            # print(tmp[0])
            line = ppg.readline()
            continue
        tmp.append(0)
        maxNum = len(tmp)-1
        for i in range(0, len(tmp)-1):
            if(float(tmp[i]) > float(tmp[maxNum])):
                maxNum = i
        nbest.write(plist[maxNum] + "\n")
        line = ppg.readline()