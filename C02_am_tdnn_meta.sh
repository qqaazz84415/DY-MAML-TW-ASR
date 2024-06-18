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
dir_tdnn_meta=$dir_tdnn/tdnn_chain_meta
dir_meta=$dir_data_base/train_meta
dir_ivec_meta=$dir_source_base/feature_meta_ivector

mfcc_config=conf/mfcc_hires.conf  # high-resolution MFCC

rm -rf $dir_tdnn_meta
mkdir -p $dir_tdnn_meta
# cp -r $dir_lang $dir_tdnn/lang
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

stage=4  # assign the start stage
meta_round=4
shots=2000
slot=( 'ca' 'en' 'jp' 'md' 'th' )
trainer_input_model=
resume=false
resume_round=2

# ---------------------------------------------------------
# <--- Execute Scripts --->

echo "============================================================================"
echo "=                      Training TDNN Acoustic Model                        ="
echo "============================================================================"

echo "-------------------- [Check files] --------------------"
for f in $dir_feat_hires/feats.scp $dir_feat_lores/feats.scp \
    $dir_feat_ivec/ivector_online.scp $dir_gmm/final.mdl $dir_ali/ali.1.gz; do
  [ ! -f $f ] && echo "Expected file $f to exist" && exit 1
done

if [ $stage -le 1 ]; then
  echo "-------------------- [stage 1: Lattices] --------------------"
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments

  for x in ca jp th en md
  do
    echo "===> execute steps/align_fmllr_lats.sh <==="
    steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" \
      $dir_source_base/feature_ivector_$x/train $dir_source_base/lang_$x $dir_target_base/am_gmm_$x/lda_mllt $dir_tdnn/lattices_$x
    rm $dir_tdnn/lattices_$x/fsts.*.gz  # save space
  done
fi

if [ $stage -le 2 ]; then
  echo "-------------------- [stage 2: Lang Topology] --------------------"
  # Creating lang directory with chain-type topology
  for x in ca jp th en md
  do
    silphonelist=$(cat $dir_tdnn/lang_$x/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $dir_tdnn/lang_$x/phones/nonsilence.csl) || exit 1;

    echo "===> execute steps/nnet3/chain/gen_topo.py <==="
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$dir_tdnn/lang_$x/topo
  done
fi

if [ $stage -le 3 ]; then
  echo "-------------------- [stage 3: Tree] --------------------"
  # Build a tree using our new topology
  for x in ca jp th en md
  do
    echo "===> execute steps/nnet3/chain/build_tree.sh <==="
    steps/nnet3/chain/build_tree.sh \
      --frame-subsampling-factor 3 \
      --context-opts "--context-width=2 --central-position=1" \
      --cmd "$train_cmd" 3500 $dir_source_base/feature_ivector_$x/train \
      $dir_tdnn/lang_$x $dir_target_base/am_gmm_$x/lda_mllt_ali $dir_tdnn/tree_$x
  done
fi

if [ $stage -le 4 ]; then
  echo "-------------------- [stage 4: Neural Nerwork Configs] --------------------"
  # creating neural net configs using the xconfig parser
  mkdir -p $dir_tdnn_meta/configs
  
  for ((i=0; i < ${#slot[@]}; i++))
  do
    num_targets=$(tree-info $dir_tdnn/tree_${slot[$i]}/tree |grep num-pdfs|awk '{print $2}')
    learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
    opts="l2-regularize=0.01"
    output_opts="l2-regularize=0.0025"

    # Comparing to KY's setting: dim 512->448, target-rms=0.5->, (output, output-xent)->bottleneck-dim=320, l2-regularize=0.0025->l2-regularize=0.005
    cat <<EOF > $dir_tdnn_meta/configs/initial_${slot[$i]}.xconfig
    input dim=100 name=ivector
    input dim=40 name=input

    # please note that it is important to have input layer with the name=input
    # as the layer immediately preceding the fixed-affine-layer to enable
    # the use of short notation for the descriptor
    fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=${dir_tdnn_meta}/configs/lda.mat

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
    relu-batchnorm-layer name=prefinal-chain ${opts} input=tdnn8 dim=512 target-rms=0.5
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
    cat <<EOF > $dir_tdnn_meta/configs/s_${slot[$i]}.xconfig
      # adding the layers for chain branch
      relu-batchnorm-layer name=prefinal-chain ${opts} input=tdnn8.batchnorm dim=512 target-rms=0.5
      output-layer name=output ${output_opts} include-log-softmax=false dim=${num_targets} max-change=1.5

      # adding the layers for xent branch
      relu-batchnorm-layer name=prefinal-xent ${opts} input=tdnn8.batchnorm dim=512 target-rms=0.5
      output-layer name=output-xent ${output_opts} dim=${num_targets} learning-rate-factor=${learning_rate_factor} max-change=1.5
EOF

    cat <<EOF > $dir_tdnn_meta/configs/q_${slot[$i]}.xconfig
      # adding the layers for chain branch
      relu-batchnorm-layer name=prefinal-chain ${opts} input=Append(tdnn8.batchnorm,tdnn_meta8.batchnorm) dim=512 target-rms=0.5
      output-layer name=output ${output_opts} include-log-softmax=false dim=${num_targets} max-change=1.5

      # adding the layers for xent branch
      relu-batchnorm-layer name=prefinal-xent ${opts} input=Append(tdnn8.batchnorm,tdnn_meta8.batchnorm) dim=512 target-rms=0.5
      output-layer name=output-xent ${output_opts} dim=${num_targets} learning-rate-factor=${learning_rate_factor} max-change=1.5
EOF
  done

  num_targets=$(tree-info $dir_tdnn/tree/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
  opts="l2-regularize=0.01"
  output_opts="l2-regularize=0.0025"

  cat <<EOF > $dir_tdnn_meta/configs/target.xconfig
    # adding the layers for chain branch
    relu-batchnorm-layer name=prefinal-chain ${opts} input=tdnn_meta8.batchnorm dim=512 target-rms=0.5
    output-layer name=output ${output_opts} include-log-softmax=false dim=${num_targets} max-change=1.5

    # adding the layers for xent branch
    relu-batchnorm-layer name=prefinal-xent ${opts} input=tdnn_meta8.batchnorm dim=512 target-rms=0.5
    output-layer name=output-xent ${output_opts} dim=${num_targets} learning-rate-factor=${learning_rate_factor} max-change=1.5
EOF

fi

if [ $stage -le 5 ]; then
  echo "------------------ [stage 5: Meta-Training] ------------------"

  if [ $resume == false ]; then
    resume_round=0
  fi
  for (( pass=0; pass<$meta_round; pass=pass+1 ))
  do
    rm -rf $dir_meta
    rm -rf $dir_ivec_meta
    # ===============================> Sampling data <==================================
    echo "===> Shuffling the order of language <==="
    slot=( $(shuf -e "${slot[@]}") )
    echo "===> Sampling training data for pass $pass <==="
    for ((i=0; i < ${#slot[@]}; i++))
    do
      # ===================> Sampling support set <===================
      mkdir -p $dir_meta/$i/train
      paste -d ':' $dir_data_base/train_${slot[$i]}/wav.scp $dir_data_base/train_${slot[$i]}/utt2spk $dir_data_base/train_${slot[$i]}/text | shuf -n $shots | awk -v FS=":" '{ print $1 >> "data/train_meta/wav.scp" ; print $2 >> "data/train_meta/utt2spk" ; print $3 >> "data/train_meta/text" }'
      mv $dir_meta/wav.scp $dir_meta/$i/train/wav.scp
      mv $dir_meta/utt2spk $dir_meta/$i/train/utt2spk
      mv $dir_meta/text $dir_meta/$i/train/text

      echo "===> execute utils/fix_data_dir.sh <==="
      utils/fix_data_dir.sh $dir_meta/$i/train

      # ====================> Sampling query set <====================
      mkdir -p $dir_meta/${i}_q/train
      paste -d ':' $dir_data_base/train_${slot[$i]}/wav.scp $dir_data_base/train_${slot[$i]}/utt2spk $dir_data_base/train_${slot[$i]}/text | shuf -n $shots | awk -v FS=":" '{ print $1 >> "data/train_meta/wav.scp" ; print $2 >> "data/train_meta/utt2spk" ; print $3 >> "data/train_meta/text" }'
      mv $dir_meta/wav.scp $dir_meta/${i}_q/train/wav.scp
      mv $dir_meta/utt2spk $dir_meta/${i}_q/train/utt2spk
      mv $dir_meta/text $dir_meta/${i}_q/train/text

      echo "===> execute utils/fix_data_dir.sh <==="
      utils/fix_data_dir.sh $dir_meta/${i}_q/train
      
      # ====================================> MFCC <=======================================
      # ===================> Support set <===================
      echo "==========> Extracting MFCC feature <=========="
      utils/utt2spk_to_spk2utt.pl $dir_meta/$i/train/utt2spk > $dir_meta/$i/train/spk2utt || exit 1;

      echo "===> execute steps/make_mfcc.sh <==="
      steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config $mfcc_config \
        $dir_meta/$i/train  $dir_meta/$i/log  $dir_meta/$i/scp_ark || exit 1;

      echo "===> execute steps/compute_cmvn_stats.sh <==="
      steps/compute_cmvn_stats.sh $dir_meta/$i/train $dir_meta/$i/log $dir_meta/$i/scp_ark || exit 1;

      echo "===> execute utils/fix_data_dir.sh <==="
      utils/fix_data_dir.sh $dir_meta/$i/train || exit 1;

      # ====================> Query set <====================
      echo "==========> Extracting MFCC feature <=========="
      utils/utt2spk_to_spk2utt.pl $dir_meta/${i}_q/train/utt2spk > $dir_meta/${i}_q/train/spk2utt || exit 1;

      echo "===> execute steps/make_mfcc.sh <==="
      steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj --mfcc-config $mfcc_config \
        $dir_meta/${i}_q/train  $dir_meta/${i}_q/log  $dir_meta/${i}_q/scp_ark || exit 1;

      echo "===> execute steps/compute_cmvn_stats.sh <==="
      steps/compute_cmvn_stats.sh $dir_meta/${i}_q/train $dir_meta/${i}_q/log $dir_meta/${i}_q/scp_ark || exit 1;

      echo "===> execute utils/fix_data_dir.sh <==="
      utils/fix_data_dir.sh $dir_meta/${i}_q/train || exit 1;

      # ==================================> i-Vector <=====================================
      # ===================> Support set <===================
      echo "==========> Extracting i-vector feature of support set ${slot[${i}]} <=========="
      mkdir -p $dir_ivec_meta/$i
      cp -r $dir_meta/$i/train $dir_ivec_meta/$i/train

      echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
      steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
        $dir_ivec_meta/$i/train $dir_source_base/feature_ivector_${slot[$i]}/ivector_extractor $dir_ivec_meta/$i/scp_ark

      # ====================> Query set <====================
      echo "===========> Extracting i-vector feature of query set ${slot[${i}]} <==========="
      mkdir -p $dir_ivec_meta/${i}_q
      cp -r $dir_meta/${i}_q/train $dir_ivec_meta/${i}_q/train

      echo "===> execute steps/online/nnet2/extract_ivectors_online.sh <==="
      steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
        $dir_ivec_meta/${i}_q/train $dir_source_base/feature_ivector_${slot[$i]}/ivector_extractor $dir_ivec_meta/${i}_q/scp_ark
    done

    # ==================================> Model Training <==================================
    echo "===> Meta-Training round $pass <==="
    for ((i=0; i < ${#slot[@]}; i++))
    do
      # =============================> Modify the model config <=============================
      echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
      if [ $i -gt 0 -o $pass -gt 0 ]; then
        steps/nnet3/xconfig_to_configs.py --existing-model $dir_tdnn_meta/final.mdl --xconfig-file $dir_tdnn_meta/configs/s_${slot[$i]}.xconfig --config-dir $dir_tdnn_meta/configs
        $train_cmd $dir_tdnn_meta/log/generate_input_mdl_${pass}_training${i}.log \
          nnet3-am-copy --raw=true $dir_tdnn_meta/final.mdl - \| \
          nnet3-init --srand=1 - $dir_tdnn_meta/configs/final.config $dir_tdnn_meta/input.raw || exit 1;
        trainer_input_model="--trainer.input-model=$dir_tdnn_meta/input.raw"
      else
        steps/nnet3/xconfig_to_configs.py --xconfig-file $dir_tdnn_meta/configs/initial_${slot[$i]}.xconfig --config-dir $dir_tdnn_meta/configs
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
        --tree-dir=$dir_tdnn/tree_${slot[$i]} \
        --lat-dir=$dir_tdnn/lattices_${slot[$i]} \
        --dir=$dir_tdnn/tdnn_chain_meta || exit 1;
    
      # =============================> Modify the model config <=============================
      echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
      steps/nnet3/xconfig_to_configs.py --existing-model $dir_tdnn_meta/final.mdl --xconfig-file $dir_tdnn_meta/configs/q_${slot[$i]}.xconfig --config-dir $dir_tdnn_meta/configs
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
        --tree-dir=$dir_tdnn/tree_${slot[$i]} \
        --lat-dir=$dir_tdnn/lattices_${slot[$i]} \
        --dir=$dir_tdnn/tdnn_chain_meta || exit 1;
    done
  done
fi

if [ $stage -le 6 ]; then
  echo "------------------ [stage 6: Network Config] ------------------"
  echo "===> initing the network for meta-testing <==="
  echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
  steps/nnet3/xconfig_to_configs.py --existing-model $dir_tdnn_meta/final.mdl --xconfig-file $dir_tdnn_meta/configs/target.xconfig --config-dir $dir_tdnn_meta/configs
  $train_cmd $dir_tdnn_meta/log/generate_input_mdl.log \
    nnet3-am-copy --raw=true $dir_tdnn_meta/final.mdl - \| \
    nnet3-init --srand=1 - $dir_tdnn_meta/configs/final.config $dir_tdnn_meta/input.raw || exit 1;
  trainer_input_model="--trainer.input-model=$dir_tdnn_meta/input.raw"
fi

if [ $stage -le 7 ]; then
  echo "------------------ [stage 7: Meta-Testing] ------------------"
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
    --trainer.num-epochs=4 \
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
    --dir=$dir_tdnn/tdnn_chain_meta || exit 1;
fi

# ---------------------------------------------------------

echo ""
echo "*************************************"
echo "***** TDNN Acoustic Model Done. *****"
echo "*************************************"
