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
dir_tdnn_model=$dir_tdnn/tdnn_chain

rm -rf $dir_tdnn_model
mkdir -p $dir_tdnn_model
rm -rf $dir_tdnn/lang
cp -r $dir_lang $dir_tdnn/lang

# ---------------------------------------------------------
# <--- Parameter --->

# LSTM/chain options
train_stage=-10
xent_regularize=0.1

# training options
remove_egs=true

stage=4  # assign the start stage

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

  echo "===> execute steps/align_fmllr_lats.sh <==="
  steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" \
    $dir_feat_lores $dir_lang $dir_gmm $dir_tdnn/lattices
  rm $dir_tdnn/lattices/fsts.*.gz  # save space
fi

if [ $stage -le 2 ]; then
  echo "-------------------- [stage 2: Lang Topology] --------------------"
  # Creating lang directory with chain-type topology

  silphonelist=$(cat $dir_tdnn/lang/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $dir_tdnn/lang/phones/nonsilence.csl) || exit 1;

  echo "===> execute steps/nnet3/chain/gen_topo.py <==="
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$dir_tdnn/lang/topo
fi

if [ $stage -le 3 ]; then
  echo "-------------------- [stage 3: Tree] --------------------"
  # Build a tree using our new topology

  echo "===> execute steps/nnet3/chain/build_tree.sh <==="
  steps/nnet3/chain/build_tree.sh \
    --frame-subsampling-factor 3 \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$train_cmd" 3500 $dir_feat_lores \
    $dir_tdnn/lang $dir_ali $dir_tdnn/tree
fi

if [ $stage -le 4 ]; then
  echo "-------------------- [stage 4: Neural Nerwork Configs] --------------------"
  # creating neural net configs using the xconfig parser

  mkdir -p $dir_tdnn_model/configs

  num_targets=$(tree-info $dir_tdnn/tree/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
  opts="l2-regularize=0.01"
  output_opts="l2-regularize=0.0025"

  # Comparing to KY's setting: dim 512->448, target-rms=0.5->, (output, output-xent)->bottleneck-dim=320, l2-regularize=0.0025->l2-regularize=0.005
  cat <<EOF > $dir_tdnn_model/configs/network.xconfig
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

  echo "===> execute steps/nnet3/xconfig_to_configs.py <==="
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir_tdnn_model/configs/network.xconfig --config-dir $dir_tdnn_model/configs
fi

if [ $stage -le 5 ]; then
  echo "-------------------- [stage 5: Training] --------------------"

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
    --dir=$dir_tdnn/tdnn_chain || exit 1;

fi

# ---------------------------------------------------------

echo ""
echo "*************************************"
echo "***** TDNN Acoustic Model Done. *****"
echo "*************************************"
