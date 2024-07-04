## System Requirements and Preparations
###### Python 3, NumPy

###### The latest version of Kaldi
###### If the CUDA version changes, you need to re-download and compile Kaldi. The compilation commands are as follows:
    user@computer:~$ cd path/to/your/kaldi/tools
    user@computer:path/to/your/kaldi/tools$ ./extras/check_dependencies.sh  # Check dependencies
    user@computer:path/to/your/kaldi/tools$ make -j 8  # You can adjust the -j value to increase compilation speed
    user@computer:path/to/your/kaldi/tools$ cd path/to/your/kaldi/src
    user@computer:path/to/your/kaldi/src$ ./configure --shared
    user@computer:path/to/your/kaldi/src$ make depend -j 8  # You can adjust the -j value to increase compilation speed
    user@computer:path/to/your/kaldi/src$ make -j 8
###### Place this folder directly in path/to/your/kaldi/egs (or upload it to egs and then extract it)
###### Check the existence of each folder path to avoid mistakes or unnecessary bugs
## Structure
###### The system consists of several main processes, along with various settings. Here's an overview of the overall folder structure:
- alignment folder: Stores alignment data, generated by X03_get_frame_ali.sh
- conf folder: Stores configuration files for MFCC and CMVN feature extraction
- data folder: Contains various training data, roughly including the following:
- dict: Dictionary data for each language
  * lm: Language model training data and vocabulary for each language
  * train/test: Stores data for each language or training dataset, including the following files:
    * utt2spk: Information about which speaker uttered each sentence
    * text: The transcript of each sentence (the ground truth)
    * wav.scp: The location data of each sentence (data path)
  * wav: Stores soft links to the audio files of each corpus, see Instructions for details
- local folder: Stores auxiliary scripts, with detailed documentation
- log folder: Stores logs of each execution, automatically generated during each run
- nbest folder: Used for calculating IQ previously, can be ignored if you are not using the same method
- steps and utils folders: Contain many useful Kaldi scripts, including those for organizing training data and extracting various features. My custom WER, CER, and PER scripts are also here
- cmd.sh: Command for specifying CPU parallel jobs, usually using run.pl, no changes needed if running on a server
- init.sh: Contains global settings for folder paths, parameters, etc., referenced in various .sh files
- path.sh: File specifying the Kaldi folder path, checked before running Kaldi scripts. No need to modify if this folder is placed in egs; you can modify if needed
- Main process series .sh files: Divided into general and meta-learning versions, introduced below:
  * A series: Language data processing, including dictionary data, ngram model construction, etc.
  * B series: Includes MFCC feature extraction for language data, GMM alignment model training, and GMM-HMM construction
  * C series: Mainly includes i-Vector feature extraction for language data, TDNN acoustic model training, and TDNN-HMM construction
  * D series: Final decoding stage
  * Each version has both general and meta-learning versions
- X01_IQ series: Scripts for calculating IQ using PPG and alignment information, can be ignored if not needed
- X01_PPG.sh: Script for calculating posterior probabilities, just adjust the data paths to get the .ark files for posterior probabilities
- X02_text2phone.sh: Script for converting sentences to phone sequences, just adjust the data paths
- X03_get_frame_ali.sh: Script for extracting GMM alignment model information, used with gt_ali.py in the alignment folder to convert alignment information into a readable format
## Instructions
### Granting Permissions
- First, enter the following command to grant execution permissions to all files:
```terminal=
    user@computer:/path/to/kaldi/egs/project$ chmod +x . -R
```
- Ensure all system requirements are met
### Setting Up Soft Links
- Reconnect any invalid soft links, usually for linking speech data. Refer to the data paths in wav.scp files in each training data folder (usually in train_xxx folders). The method is as follows:
```terminal=
      user@computer:/path/to/kaldi/egs/project$ cd data/wav
      user@computer:/path/to/kaldi/egs/project/data/wav$ ln -s path/to/your/data .  # This command links the folder with the original name
```
### Running the Program
- Enter ./run.sh to run the program, and add the GPU number if necessary (CUDA_VISIBLE_DEVICES)
- run.sh has different versions (general, meta-learning), check which version to run beforehand
```terminal=
      # General version
      user@computer:/path/to/kaldi/egs/project$ ./run.sh
      # Meta-learning version
      user@computer:/path/to/kaldi/egs/project$ ./run_meta.sh
      # Other meta-learning versions
      user@computer:/path/to/kaldi/egs/project$ ./run_meta_r.sh
      # Version with specified GPU
      user@computer:/path/to/kaldi/egs/project$ CUDA_VISIBLE_DEVICES=0,1,2 ./run.sh
```
### Modifying Processes
- You can modify paths, parameters, etc., in the various A, B, C, D process .sh files to achieve your desired results

