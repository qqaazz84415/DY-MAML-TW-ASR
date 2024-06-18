import sys
import argparse

parser = argparse.ArgumentParser(description='Calculate IQ from the data of each language')
parser.add_argument('dir', help="directory of utt2dur")
args = parser.parse_args()

dir = args.dir

def main():
    durCount = 0.0
    duration = open(dir + "/utt2dur", "r")
    out = open(dir + "/total_duration.txt", "w")
    for line in duration:
        durlist = line.split()
        durCount += float(durlist[1])
    hourOnly = float(durCount/3600)
    hour = int(durCount/3600)
    min = int((durCount%3600)/60)
    sec = int((durCount%3600)%60)
    out.write("Total duration: " + str(hour) + ":" + str(min) + ":" + str(sec) + "\n")
    out.write("Total duration(hour): " + str(hourOnly) + "\n")
    
if __name__ == "__main__":
    main()