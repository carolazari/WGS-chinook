#!/bin/bash
#SCBATH --job-name=snk-chinook
#SBATCH --output=snk-chinook.txt

#SBATCH --mail-user=carolina.lazari@noaa.gov
#SBATCH --mail-type=ALL
#SBATCH -p standard
#SBATCH -t 10:00:00
#SBATCH --nodes=2

##commands to run
conda activate snakemake-8.5.3
module load bio/samtools
module load bio/bcftools
module load aligners/bwa-mem2
snakemake -p results/vcf/all.vcf.gz --cores 2
