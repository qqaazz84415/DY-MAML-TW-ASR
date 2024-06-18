import sys

langs = ['ca', 'en', 'jp', 'md', 'th']
for lang in langs:
    gt = open(lang + '/gtframe.txt', "w")
    print("==> Processing " + lang + " <==")
    for i in range(1, 9):
        ali = open(lang + '/ali.' + str(i) + '.txt', "r")
        frame = ali.readline()
        phone = ali.readline()
        enter = ali.readline()
        while frame and phone:
            alilist = frame.split()
            plist = phone.split()
            #print(alilist)
            pos = 1
            prevframe = 0
            for j in range(1, len(alilist)):
                if (alilist[j]=='['):
                    count = 0
                elif (alilist[j]==']'):
                    word = plist[pos]
                    noBEIS = word[:-2] if (word[-1]=='B' or word[-1]=='E' or word[-1]=='I' or word[-1]=='S') else word
                    notone = noBEIS[:-1] if (noBEIS[-1].isdigit()) else noBEIS
                    gt.write(alilist[0] + " " + str(prevframe+1) + " " + str(prevframe+count) + " " + notone + " " + noBEIS + " " + word + "\n")
                    prevframe = prevframe + count
                    pos = pos + 1
                else:
                    count = count + 1
            frame = ali.readline()
            phone = ali.readline()
            enter = ali.readline()
    print("==> " + lang + " done <==")