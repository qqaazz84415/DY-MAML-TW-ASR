#!/bin/bash

# ---------------------------------------------------------
# <--- Init --->

. ./init.sh

# ---------------------------------------------------------
# <--- Directory --->

dir_lang=$dir_source_lang
dir_feat_hires=$dir_source_feat_ivec/train  # high-resolution MFCC features
dir_feat_lores=$dir_source_feat_ivec/train  # low-resolution MFCC features
dir_feat_ivec=$dir_source_feat_ivec/scp_ark
dir_gmm=$dir_target_gmm/lda_mllt
dir_ali=$dir_target_gmm/lda_mllt_ali
dir_tdnn=$dir_target_tdnn
dir_lat_meta=$dir_tdnn/lattices_meta
dir_tree_meta=$dir_tdnn/tree_meta
dir_gmm_meta=$dir_target_base/am_gmm_meta
dir_gmm_hmm_meta=$dir_target_base/graph_gmm_hmm_meta
dir_tdnn_meta=$dir_tdnn/tdnn_chain_meta2
dir_meta=$dir_data_base/train_meta2
dir_ivec_meta=$dir_source_base/feature_meta_ivector2
dir_log_prob=$dir_data_base/logprob
dir_dist=$dir_data_base/distribution

mfcc_config=conf/mfcc_hires.conf  # high-resolution MFCC

#rm -rf $dir_tdnn
#mkdir -p $dir_tdnn
#cp -r $dir_lang $dir_tdnn/lang
# cp -r $dir_lang_ca $dir_tdnn/lang_ca
# cp -r $dir_lang_jp $dir_tdnn/lang_jp
# cp -r $dir_lang_th $dir_tdnn/lang_th
# cp -r $dir_lang_en $dir_tdnn/lang_en
# cp -r $dir_lang_md $dir_tdnn/lang_md

# ---------------------------------------------------------
# <--- Parameter --->

# LSTM/chain options
train_stage=-10
xent_regularize=0.1

# training options
remove_egs=true

# stage=4  # assign the start stage
meta_round=5
slot=( 'ca' 'en' 'jp' 'md' 'th' )
trainer_input_model=
st_parameter="-a"
nj=16

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "==========================================================================="
echo "=                          Meta-Learning of TDNN                          ="
echo "==========================================================================="

echo "-------------------- [Meta-Training] --------------------"
for (( pass=0; pass<$meta_round; pass=pass+1 ))
do
  echo "===> Meta-Training for round $pass <==="
  if [ ! -f "$dir_dist/dist.txt" ]; then # if the initial distribution is not exist, create it
    python3 local/dist.py $dir_log_prob $dir_data_base $dir_dist $pass
  fi
  # ===============================> Sampling data <==================================
  echo "===> Randomly shuffling the order of language <==="
  slot=( $(shuf -e "${slot[@]}") )
  echo "===> Sampling meta-training data and extract MFCC feature <==="
  for ((i=0; i < ${#slot[@]}; i++))
  do
    # ===============> Support set <===============
    echo "===> Sampling support set of ${slot[${i}]} <==="
    rm -rf $dir_meta/$i
    mkdir -p $dir_meta/$i/train
    python3 local/sumTreeArgs.py $st_parameter $dir_dist ${slot[$i]} $dir_data_base/train_${slot[$i]} $dir_meta/$i/train

    echo "===> execute utils/fix_data_dir.sh <==="
    utils/fix_data_dir.sh $dir_meta/$i/train
    mv $dir_data_base/train_${slot[$i]}/samplingResult.txt $dir_data_base/train_${slot[$i]}/samplingResult_${pass}_s.txt

    # ================> Query set <================
    echo "====> Sampling qury set of ${slot[${i}]} <===="
    rm -rf $dir_meta/${i}_q
    mkdir -p $dir_meta/${i}_q/train
    python3 local/sumTreeArgs.py $st_parameter $dir_dist ${slot[$i]} $dir_data_base/train_${slot[$i]} $dir_meta/${i}_q/train

    echo "===> execute utils/fix_data_dir.sh <==="
    utils/fix_data_dir.sh $dir_meta/${i}_q/train
    mv $dir_data_base/train_${slot[$i]}/samplingResult.txt $dir_data_base/train_${slot[$i]}/samplingResult_${pass}_q.txt

    # ====================> MFCC <====================
    for x in $i ${i}_q
    do
      echo "==========> Extracting MFCC feature <=========="
      utils/utt2spk_to_spk2utt.pl $dir_meta/$x/train/utt2spk > $dir_meta/$x/train/spk2utt || exit 1;

      echo "===> execute steps/make_mfcc.sh <==="
      steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config $mfcc_config \
        $dir_meta/$x/train  $dir_meta/$x/log  $dir_meta/$x/scp_ark || exit 1;

      echo "===> execute steps/compute_cmvn_stats.sh <==="
      steps/compute_cmvn_stats.sh $dir_meta/$x/train $dir_meta/$x/log $dir_meta/$x/scp_ark || exit 1;

      echo "===> execute utils/fix_data_dir.sh <==="
      utils/fix_data_dir.sh $dir_meta/$x/train || exit 1;
    done
  done
  echo "=====> GMM Acoustic Model and graph <====="
  rm -rf $dir_gmm_meta $dir_gmm_hmm_meta
  for ((i=0; i < ${#slot[@]}; i++))
  do
    for x in $i ${i}_q
    do
      mkdir -p $dir_gmm_meta/$x
      mkdir -p $dir_gmm_hmm_meta/$x
      # ---------- [Training monophone] ----------
      echo "===> execute steps/train_mono.sh <==="
      steps/train_mono.sh --cmd "$train_cmd" --nj $nj --cmvn-opts "--norm-means=true --norm-vars=true" \
        $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/monophone || exit 1;

      echo "===> execute steps/align_si.sh <==="
      steps/align_si.sh --cmd "$train_cmd" --nj $nj \
        $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/monophone $dir_gmm_meta/$x/monophone_ali || exit 1;

      # ---------- [Training triphone - 1] ----------
      echo "===> execute steps/train_deltas.sh <==="
      steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
        4000 80000 $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/monophone_ali $dir_gmm_meta/$x/triphone1 || exit 1;

      echo "===> execute steps/align_si.sh <==="
      steps/align_si.sh --cmd "$train_cmd" --nj $nj \
        $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/triphone1 $dir_gmm_meta/$x/triphone1_ali || exit 1;

      # ---------- [Training triphone - 2] ----------
      echo "===> execute steps/train_deltas.sh <==="
      steps/train_deltas.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
        4000 80000 $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/triphone1_ali $dir_gmm_meta/$x/triphone2 || exit 1;

      echo "===> execute steps/align_si.sh <==="
      steps/align_si.sh --cmd "$train_cmd" --nj $nj \
        $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/triphone2 $dir_gmm_meta/$x/triphone2_ali || exit 1;

      # ---------- [Training lda_mllt] ----------
      echo "===> execute steps/train_lda_mllt.sh <==="
      steps/train_lda_mllt.sh --cmd "$train_cmd" --cmvn-opts "--norm-means=true --norm-vars=true" \
        8000 80000 $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/triphone2_ali $dir_gmm_meta/$x/lda_mllt || exit 1;

      echo "===> execute steps/align_fmllr.sh <==="  # if apply SAT, may should change this to align_si.sh
      steps/align_fmllr.sh --cmd "$train_cmd" --nj $nj \
        $dir_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/lda_mllt $dir_gmm_meta/$x/lda_mllt_ali

      echo "===> execute utils/mkgraph.sh <==="
      utils/mkgraph.sh $dir_target_base/lm_${slot[$i]} $dir_gmm_meta/$x/lda_mllt $dir_gmm_hmm_meta/$x || exit 1;
    done
  done
  echo "=======> i-Vector Extraction <======="
  rm -rf $dir_ivec_meta
  for ((i=0; i < ${#slot[@]}; i++))
  do
    for x in $i ${i}_q
    do
      mkdir -p $dir_ivec_meta/$x
      cp -r $dir_meta/$x/train $dir_ivec_meta/$x/train
      echo "-------------------- [sub-stage 1: PCA & UBM] --------------------"
      # Computing a subset of data to train the diagonal UBM.
      num_utt_total=$(wc -l <$dir_ivec_meta/$x/train/utt2spk)
      num_utt_sub=$[$num_utt_total/4]  # using a subset of about a quarter of the data

      echo "===> execute utils/data/subset_data_dir.sh <==="
      utils/data/subset_data_dir.sh $dir_ivec_meta/$x/train $num_utt_sub $dir_ivec_meta/$x/train_subset

      # Computing a PCA transform from the hires data.
      echo "===> execute steps/online/nnet2/get_pca_transform.sh <==="
      steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
        --splice-opts "--left-context=3 --right-context=3" \
        --max-utts 10000 --subsample 2 \
        $dir_ivec_meta/$x/train_subset \
        $dir_ivec_meta/$x/pca_transform

      # Training the diagonal UBM (Use 512 Gaussians in the UBM).
      echo "===> execute steps/online/nnet2/train_diag_ubm.sh <==="
      steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj $nj \
        --num-frames 700000 \
        --num-threads 32 \
        $dir_ivec_meta/$x/train_subset 512 \
        $dir_ivec_meta/$x/pca_transform $dir_ivec_meta/$x/diag_ubm

      echo "-------------------- [sub-stage 2: i-Vector - training] --------------------"=
      echo "===> execute steps/online/nnet2/train_ivector_extractor.sh <==="
      steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj $nj \
        $dir_ivec_meta/$x/train $dir_ivec_meta/$x/diag_ubm $dir_ivec_meta/$x/ivector_extractor || exit 1;

      echo "-------------------- [sub-stage 3: i-Vector - extraction] --------------------"
      echo "===> execute utils/data/modify_speaker_info.sh <==="
      utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
        $dir_ivec_meta/$x/train $dir_ivec_meta/$x/train_modify_speaker

      echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
      steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
        $dir_ivec_meta/$x/train_modify_speaker $dir_ivec_meta/$x/ivector_extractor $dir_ivec_meta/$x/scp_ark
    done
  done
  echo "==========> Check files <=========="
  for ((i=0; i < ${#slot[@]}; i++))
  do
    for x in $i ${i}_q
    do
      for f in $dir_ivec_meta/$x/train/feats.scp $dir_ivec_meta/$x/scp_ark/ivector_online.scp \
          $dir_gmm_meta/$x/lda_mllt/final.mdl $dir_gmm_meta/$x/lda_mllt_ali/ali.1.gz; do
        [ ! -f $f ] && echo "Expected file $f to exist" && exit 1
      done
    done
  done
  echo "==========> Lattices, Topo, and Tree <=========="
  for ((i=0; i < ${#slot[@]}; i++))
  do
    # ===============================> Lang Topo <==================================
    silphonelist=$(cat $dir_tdnn/lang_$x/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $dir_tdnn/lang_$x/phones/nonsilence.csl) || exit 1;

    echo "===> execute steps/nnet3/chain/gen_topo.py <==="
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$dir_tdnn/lang_$x/topo
    for x in $i ${i}_q
    do
      # ===============================> Lattices <==================================
      rm -rf $dir_lat_meta/$x
      mkdir -p $dir_lat_meta/$x
      echo "===> execute steps/align_fmllr_lats.sh <==="
      steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" \
        $dir_ivec_meta/$x/train $dir_source_base/lang_${slot[$i]} $dir_gmm_meta/$x/lda_mllt $dir_lat_meta/$x
      rm $dir_lat_meta/$x/fsts.*.gz  # save space

      # =================================> Tree <====================================
      rm -rf $dir_tree_meta/$x
      mkdir -p $dir_tree_meta/$x
      echo "===> execute steps/nnet3/chain/build_tree.sh <==="
      steps/nnet3/chain/build_tree.sh \
        --frame-subsampling-factor 3 \
        --context-opts "--context-width=2 --central-position=1" \
        --cmd "$train_cmd" 3500 $dir_ivec_meta/$x/train \
        $dir_tdnn/lang_${slot[$i]} $dir_gmm_meta/$x/lda_mllt_ali $dir_tree_meta/$x
    done
  done
  echo "==========> Network Configs <=========="
  for ((i=0; i < ${#slot[@]}; i++))
  do
    num_targets=$(tree-info $dir_tree_meta/$x/tree |grep num-pdfs|awk '{print $2}')
    learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
    opts="l2-regularize=0.01"
    output_opts="l2-regularize=0.0025"

    cat <<EOF > $dir_tdnn_meta/configs/s_$i.xconfig
    input dim=100 name=ivector
    input dim=40 name=input

    # please note that it is important to have input layer with the name=input
    # as the layer immediately preceding the fixed-affine-layer to enable
    # the use of short notation for the descriptor
    fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=${dir_tdnn}/tdnn_chain/configs/lda.mat

    # the first splicing is moved before the lda layer, so no splicing here
    relu-batchnorm-layer name=tdnn1 ${opts} dim=512
    relu-batchnorm-layer name=tdnn2 ${opts} dim=512 input=Append(-1,0,1)
    relu-batchnorm-layer name=tdnn3 ${opts} dim=512
    relu-batchnorm-layer name=tdnn4 ${opts} dim=512 input=Append(-1,0,1)
    relu-batchnorm-layer name=tdnn5 ${opts} dim=512
    relu-batchnorm-layer name=tdnn6 ${opts} dim=512 input=Append(-3,0,3)
    relu-batchnorm-layer name=tdnn7 ${opts} dim=512 input=Append(-3,0,3)
    relu-batchnorm-layer name=tdnn8 ${opts} dim=512 input=Append(-6,-3,0)
    relu-batchnorm-layer name=tdnn_meta1 ${opts} dim=512 input=lda
    relu-batchnorm-layer name=tdnn_meta2 ${opts} dim=512 input=Append(-1,0,1)
    relu-batchnorm-layer name=tdnn_meta3 ${opts} dim=512
    relu-batchnorm-layer name=tdnn_meta4 ${opts} dim=512 input=Append(-1,0,1)
    relu-batchnorm-layer name=tdnn_meta5 ${opts} dim=512
    relu-batchnorm-layer name=tdnn_meta6 ${opts} dim=512 input=Append(-3,0,3)
    relu-batchnorm-layer name=tdnn_meta7 ${opts} dim=512 input=Append(-3,0,3)
    relu-batchnorm-layer name=tdnn_meta8 ${opts} dim=512 input=Append(-6,-3,0)

    ## adding the layers for chain branch
    relu-batchnorm-layer name=prefinal-chain ${opts} dim=512 target-rms=0.5
    output-layer name=output ${output_opts} include-log-softmax=false dim=${num_targets} max-change=1.5

    # adding the layers for xent branch
    # This block prints the configs for a separate output that will be
    # trained with a cross-entropy objective in the 'chain' models... this
    # has the effect of regularizing the hidden parts of the model.  we use
    # 0.5 / args.xent_regularize as the learning rate factor- the factor of
    # 0.5 / args.xent_regularize is suitable as it means the xent
    # final-layer learns at a rate independent of the regularization
    # constant; and the 0.5 was tuned so as to make the relative progress
    # similar in the xent and regular final layers.
    relu-batchnorm-layer name=prefinal-xent ${opts} input=tdnn8 dim=512 target-rms=0.5
    output-layer name=output-xent ${output_opts} dim=${num_targets} learning-rate-factor=${learning_rate_factor} max-change=1.5
EOF

    # Comparing to KY's setting: dim 512->448, target-rms=0.5->, (output, output-xent)->bottleneck-dim=320, l2-regularize=0.0025->l2-regularize=0.005
    cat <<EOF > $dir_tdnn_meta/configs/$i.xconfig
    # adding the layers for chain branch
    relu-batchnorm-layer name=prefinal-chain ${opts} input=tdnn8.batchnorm dim=512 target-rms=0.5
    output-layer name=output ${output_opts} include-log-softmax=false dim=${num_targets} max-change=1.5

    # adding the layers for xent branch
    relu-batchnorm-layer name=prefinal-xent ${opts} input=tdnn8.batchnorm dim=512 target-rms=0.5
    output-layer name=output-xent ${output_opts} dim=${num_targets} learning-rate-factor=${learning_rate_factor} max-change=1.5
EOF
    cat <<EOF > $dir_tdnn_meta/configs/${i}_q.xconfig
    # adding the layers for chain branch
    relu-batchnorm-layer name=prefinal-chain ${opts} input=Append(tdnn8.batchnorm,tdnn_meta8.batchnorm) dim=512 target-rms=0.5
    output-layer name=output ${output_opts} include-log-softmax=false dim=${num_targets} max-change=1.5

    # adding the layers for xent branch
    relu-batchnorm-layer name=prefinal-xent ${opts} input=Append(tdnn8.batchnorm,tdnn_meta8.batchnorm) dim=512 target-rms=0.5
    output-layer name=output-xent ${output_opts} dim=${num_targets} learning-rate-factor=${learning_rate_factor} max-change=1.5
EOF
  done
  echo "==========> Meta-Training <=========="
  for ((i=0; i < ${#slot[@]}; i++))
  do
    echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
    if [ $i -gt 0 -o $pass -gt 0 ]; then
      steps/nnet3/xconfig_to_configs.py --existing-model $dir_tdnn_meta/final.mdl --xconfig-file $dir_tdnn_meta/configs/$i.xconfig --config-dir $dir_tdnn_meta/configs
      $train_cmd $dir_tdnn_meta/log/generate_input_mdl_${pass}_training${i}.log \
        nnet3-am-copy --raw=true $dir_tdnn_meta/final.mdl - \| \
        nnet3-init --srand=1 - $dir_tdnn_meta/configs/final.config $dir_tdnn_meta/input.raw || exit 1;
      trainer_input_model="--trainer.input-model=$dir_tdnn_meta/input.raw"
    else
      steps/nnet3/xconfig_to_configs.py --xconfig-file $dir_tdnn_meta/configs/s_$i.xconfig --config-dir $dir_tdnn_meta/configs
    fi
    echo "===> Training the model with support set <==="
    steps/nnet3/chain/train.py --stage=$train_stage \
      --cmd="$decode_cmd" \
      --feat.online-ivector-dir=$dir_ivec_meta/$i/scp_ark \
      --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
      --chain.xent-regularize=$xent_regularize \
      --chain.leaky-hmm-coefficient=0.1 \
      --chain.l2-regularize=0.00005 \
      --chain.apply-deriv-weights=false \
      --chain.lm-opts="--num-extra-lm-states=2000" \
      --trainer.srand=$srand \
      --trainer.max-param-change=2.0 \
      --trainer.num-epochs=1 \
      --trainer.frames-per-iter=3000000 \
      --trainer.optimization.num-jobs-initial=1 \
      --trainer.optimization.num-jobs-final=1 \
      --trainer.optimization.initial-effective-lrate=0.001 \
      --trainer.optimization.final-effective-lrate=0.0001 \
      --trainer.num-chunk-per-minibatch=128 \
      --trainer.optimization.momentum=0.0 \
      $trainer_input_model \
      --egs.chunk-width=$chunk_width \
      --egs.chunk-left-context=0 \
      --egs.chunk-right-context=0 \
      --egs.chunk-left-context-initial=0 \
      --egs.chunk-right-context-final=0 \
      --egs.dir="" \
      --egs.opts="--frames-overlap-per-eg 0" \
      --cleanup.remove-egs=$remove_egs \
      --use-gpu=$use_gpu \
      --reporting.email="" \
      --feat-dir=$dir_ivec_meta/$i/train \
      --tree-dir=$dir_tree_meta/$i \
      --lat-dir=$dir_lat_meta/$i \
      --dir=$dir_tdnn/tdnn_chain_meta2 || exit 1;

    # extract the logprob from log file
    python3 local/extractlogprob.py $dir_tdnn_meta/log ${slot[$i]} $pass support $dir_data_base/logprob

    # =============================> Modify the model config <=============================
    echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
    steps/nnet3/xconfig_to_configs.py --existing-model $dir_tdnn_meta/final.mdl --xconfig-file $dir_tdnn_meta/configs/${i}_q.xconfig --config-dir $dir_tdnn_meta/configs
    $train_cmd $dir_tdnn_meta/log/generate_input_mdl.log \
      nnet3-am-copy --raw=true $dir_tdnn_meta/final.mdl - \| \
      nnet3-init --srand=1 - $dir_tdnn_meta/configs/final.config $dir_tdnn_meta/input.raw || exit 1;
    trainer_input_model="--trainer.input-model=$dir_tdnn_meta/input.raw"

    echo "===> Updating the model with query set <==="
    steps/nnet3/chain/train.py --stage=$train_stage \
      --cmd="$decode_cmd" \
      --feat.online-ivector-dir=$dir_ivec_meta/${i}_q/scp_ark \
      --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
      --chain.xent-regularize=$xent_regularize \
      --chain.leaky-hmm-coefficient=0.1 \
      --chain.l2-regularize=0.00005 \
      --chain.apply-deriv-weights=false \
      --chain.lm-opts="--num-extra-lm-states=2000" \
      --trainer.srand=$srand \
      --trainer.max-param-change=2.0 \
      --trainer.num-epochs=1 \
      --trainer.frames-per-iter=3000000 \
      --trainer.optimization.num-jobs-initial=1 \
      --trainer.optimization.num-jobs-final=1 \
      --trainer.optimization.initial-effective-lrate=0.001 \
      --trainer.optimization.final-effective-lrate=0.0001 \
      --trainer.num-chunk-per-minibatch=128 \
      --trainer.optimization.momentum=0.0 \
      $trainer_input_model \
      --egs.chunk-width=$chunk_width \
      --egs.chunk-left-context=0 \
      --egs.chunk-right-context=0 \
      --egs.chunk-left-context-initial=0 \
      --egs.chunk-right-context-final=0 \
      --egs.dir="" \
      --egs.opts="--frames-overlap-per-eg 0" \
      --cleanup.remove-egs=$remove_egs \
      --use-gpu=$use_gpu \
      --reporting.email="" \
      --feat-dir=$dir_ivec_meta/${i}_q/train \
      --tree-dir=$dir_tree_meta/${i}_q \
      --lat-dir=$dir_lat_meta/${i}_q \
      --dir=$dir_tdnn/tdnn_chain_meta2 || exit 1;

    # extract the logprob from log file
    python3 local/extractlogprob.py $dir_tdnn_meta/log ${slot[$i]} $pass query $dir_data_base/logprob
  done
  echo "==========> IQ extraction <=========="
  mv $dir_tdnn_meta/final.mdl $dir_tdnn_meta/final_IQ.mdl
  # train the model to the target domain to get IQ
  echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
  steps/nnet3/xconfig_to_configs.py --existing-model $dir_tdnn_meta/final_IQ.mdl --xconfig-file $dir_tdnn_meta/configs/target.xconfig --config-dir $dir_tdnn_meta/configs
  $train_cmd $dir_tdnn_meta/log/generate_input_mdl.log \
    nnet3-am-copy --raw=true $dir_tdnn_meta/final_IQ.mdl - \| \
    nnet3-init --srand=1 - $dir_tdnn_meta/configs/final.config $dir_tdnn_meta/input.raw || exit 1;
  trainer_input_model="--trainer.input-model=$dir_tdnn_meta/input.raw"

  echo "===> execute steps/nnet3/chain/train.py <==="
  steps/nnet3/chain/train.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir=$dir_feat_ivec \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --chain.xent-regularize=$xent_regularize \
    --chain.leaky-hmm-coefficient=0.1 \
    --chain.l2-regularize=0.00005 \
    --chain.apply-deriv-weights=false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
    --trainer.num-epochs=5 \
    --trainer.frames-per-iter=3000000 \
    --trainer.optimization.num-jobs-initial=1 \
    --trainer.optimization.num-jobs-final=1 \
    --trainer.optimization.initial-effective-lrate=0.001 \
    --trainer.optimization.final-effective-lrate=0.0001 \
    --trainer.num-chunk-per-minibatch=128 \
    --trainer.optimization.momentum=0.0 \
    $trainer_input_model \
    --egs.chunk-width=$chunk_width \
    --egs.chunk-left-context=0 \
    --egs.chunk-right-context=0 \
    --egs.chunk-left-context-initial=0 \
    --egs.chunk-right-context-final=0 \
    --egs.dir="" \
    --egs.opts="--frames-overlap-per-eg 0" \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=$use_gpu \
    --reporting.email="" \
    --feat-dir=$dir_feat_hires \
    --tree-dir=$dir_tdnn/tree \
    --lat-dir=$dir_tdnn/lattices \
    --dir=$dir_tdnn/tdnn_chain_meta2 || exit 1;

  if (( pass < meta_round-1 )); then
    ./X01_IQ.sh -f $dir_tdnn_meta -r $pass

    mv $dir_tdnn_meta/final.mdl $dir_tdnn_meta/final_${pass}.mdl
    mv $dir_tdnn_meta/final_IQ.mdl $dir_tdnn_meta/final.mdl
  fi
done

# ---------------------------------------------------------

echo ""
echo "*************************************"
echo "***** TDNN Acoustic Model Done. *****"
echo "*************************************"
