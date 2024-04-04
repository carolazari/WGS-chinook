#!/bin/bash
# Job name:
#SBATCH --job-name=chinook_run1
#
# Partition - This is the queue it goes in:
#SBATCH --partition=Instruction
#
# Where to send email (optional)
#SBATCH --mail-user=clazari@ucsc.edu
#
# Number of nodes you need per job:
#SBATCH --nodes=1
#
# Memory needed for the jobs.  Try very hard to make this accurate.  DEFAULT = 4gb
#SBATCH --mem=4gb
#
# Number of tasks (one for each CPU desired for use case) (example):
#SBATCH --ntasks=1
#
# Processors per task:
# At least eight times the number of GPUs needed for nVidia RTX A5500
#SBATCH --cpus-per-task=1
#
# Number of GPUs, this can be in the format of "--gres=gpu:[1-8]", or "--gres=gpu:A5500:[1-8]" with the type included (optional)
#SBATCH --gres=gpu:1
#
# Standard output and error log
#SBATCH --output=serial_test_%j.log
#
# Wall clock limit in hrs:min:sec:
#SBATCH --time=00:00:45
#
## Command(s) to run (example):
pwd; hostname; date
echo "Running test script on a single CPU core"
sleep 5
echo "Test done!"
date
