#!/bin/bash
# Gregory Gay (greg@greggay.com)
# Initial configuration for Amazon EC2 instances.
# Run AFTER setup_ec2.sh

git clone https://github.com/Greg4cr/defects4j.git
cd defects4j
git checkout mcc-experiment
./init.sh
cp framework/lib/test_generation/generation/evosuite-1.0.5.jar framework/lib/test_generation/generation/evosuite-current.jar
cp framework/lib/test_generation/runtime/evosuite-standalone-runtime-1.0.5.jar framework/lib/test_generation/runtime/evosuite-rt.jar
export PATH=$PATH:$HOME/defects4j/framework/bin
echo 'export PATH=$PATH:/home/greg/defects4j/framework/bin' >> $HOME/.bashrc
