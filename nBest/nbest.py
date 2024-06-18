import sys

phone = open(str(sys.argv[1]+"/phones.txt"), "r")
nbest = open(str(sys.argv[1]+"/3best_prob.txt") , "w")

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
        first = second = third = len(tmp)-1
        for i in range(0, len(tmp)-1):
            if(float(tmp[i]) > float(tmp[first])):
                third = second
                second = first
                first = i
            elif(float(tmp[i]) > float(tmp[second])):
                third = second
                second = i
            elif(float(tmp[i]) > float(tmp[third])):
                third = i
        nbest.write(plist[first] + " " + plist[second] + " " + plist[third] + "\n")
        # print(str(first) + " " + str(second) + " " + str(third))
        line = ppg.readline()