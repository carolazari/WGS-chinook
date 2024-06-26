# start with some stuff to get the Snakemake version
from snakemake import __version__ as snakemake_version
smk_major_version = int(snakemake_version[0])



# import modules as needed. Also import the snakemake
# internal command to load a config file into a dict
import pandas as pd

if smk_major_version >= 8:
  from snakemake.common.configfile import _load_configfile
else:
  from snakemake.io import _load_configfile



# define rules that don't need to be run on a compute node.
# i.e. those that can be run locally.
localrules: all, genome_faidx, genome_dict



### Get a dict named config from Snakemake-Example/config.yaml
configfile: "config.yaml"




### Get the sample info table read into a pandas data frame
sample_table=pd.read_table(config["units"], dtype="str").set_index(
    "sample", drop=False
)



### Transfer values from the yaml and tabular config to
### our familiar lists, SAMPLES and CHROMOS
# Populate our SAMPLES list from the sample_table using a little
# pandas syntax
SAMPLES=sample_table["sample"].unique().tolist()

# Define CHROMOS from the values in the config file
CHROMOS=config["chromos"]



### Input Functins that use the tabular sample_info
# define a function to get the fastq path from the sample_table. This
# returns it as a dict, so we need to unpack it in the rule
#df.loc (in this case sample_table.loc) access a group of rows/columns by a label
def get_fastqs(wildcards):
  fq1=sample_table.loc[ wildcards.sample, "fq1" ]
  fq2=sample_table.loc[ wildcards.sample, "fq2" ]
  return {"r1": fq1, "r2": fq2 }

# define a function for getting the read group information
# from the sample table for each particular sample (according
# to the wildcard value)
def get_read_group(wildcards):
    """Denote sample name and platform in read group."""
    return r"-R '@RG\tID:{sample}_{sample_id}_{library}_{flowcell}_{lane}_{barcode}\tSM:{sample_id}\tPL:{platform}\tLB:{library}\tPU:{flowcell}.{lane}.{barcode}'".format(
        sample=wildcards.sample,
        sample_id=sample_table.loc[(wildcards.sample), "sample_id"],
        platform=sample_table.loc[(wildcards.sample), "platform"],
        library=sample_table.loc[(wildcards.sample), "library"],
        flowcell=sample_table.loc[(wildcards.sample), "flowcell"],
        lane=sample_table.loc[(wildcards.sample), "lane"],
        barcode=sample_table.loc[(wildcards.sample), "barcode"],
    )




### Specify rule "all"
# By default, Snakemake tries to create the input files needed
# for the first rule in the Snakefile, so we define the first
# rule to ask for results/vcf/all.vcf.gz
rule all:
  input: 
  "results/vcf/all.vcf.gz"
    
    #expand("results/hard_filtering/indels-filtered/{chromo}.vcf.gz", chromo=CHROMOS)



rule genome_faidx:
  input:
    "Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna",
  output:
    "Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna.fai",
  conda:
    "Envs/bwa2sam.yaml"
  log:
    "results/logs/genome_faidx.log",
  shell:
    "samtools faidx {input} 2> {log} "


rule genome_dict:
  input:
    "Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna",
  output:
    "Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.dict",
  conda:
    "Envs/bwa2sam.yaml"
  log:
    "results/logs/genome_dict.log",
  shell:
    "samtools dict {input} > {output} 2> {log} "


rule bwa_index:
  input:
    "Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna"
  output:
    multiext("Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna", ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac"),
  conda:
    "Envs/bwa2sam.yaml"
  log:
    out="results/logs/bwa_index/bwa_index.log",
    err="results/logs/bwa_index/bwa_index.err"
  shell:
    "bwa-mem2 index {input} > {log.out} 2> {log.err} "




rule trim_reads:
  input:
    unpack(get_fastqs)
  output:
    r1="results/trimmed/{sample}_R1.fastq.gz",
    r2="results/trimmed/{sample}_R2.fastq.gz",
    html="results/qc/fastp/{sample}.html",
    json="results/qc/fastp/{sample}.json"
  conda:
    "Envs/fastp.yaml"
  log:
    out="results/logs/trim_reads/{sample}.log",
    err="results/logs/trim_reads/{sample}.err",
  params:
    as1=config["params"]["fastp"]["adapter_sequence1"],
    as2=config["params"]["fastp"]["adapter_sequence2"],
    parm=config["params"]["fastp"]["other_options"]
  shell:
    " fastp -i {input.r1} -I {input.r2}       "
    "       -o {output.r1} -O {output.r2}     "
    "       -h {output.html} -j {output.json} "
    "  --adapter_sequence={params.as1}        "
    "  --adapter_sequence_r2={params.as2}     "
    "  {params.parm} > {log.out} 2> {log.err}                         "
    


rule map_reads:
  input:
    r1="results/trimmed/{sample}_R1.fastq.gz",
    r2="results/trimmed/{sample}_R2.fastq.gz",
    genome="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna",
    idx=multiext("Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna", ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac")
  output:
    "results/bam/{sample}.bam"
  conda:
    "Envs/bwa2sam.yaml"
  log:
    "results/logs/map_reads/{sample}.log"
  threads: 2
  resources:
    mem_mb=7480,
    time="01:00:00"
  params:
    RG=get_read_group
  shell:
    " (bwa-mem2 mem -t {threads} {params.RG} {input.genome} {input.r1} {input.r2} | "
    " samtools view -u | "
    " samtools sort - > {output}) 2> {log} "




rule mark_duplicates:
  input:
    "results/bam/{sample}.bam"
  output:
    bam="results/mkdup/{sample}.bam",
    bai="results/mkdup/{sample}.bai",
    metrics="results/qc/mkdup_metrics/{sample}.metrics"
  conda:
    "Envs/gatk.yaml"
  log:
    "results/logs/mark_duplicates/{sample}.log"
  shell:
    " gatk MarkDuplicates  "
    "  --CREATE_INDEX "
    "  -I {input} "
    "  -O {output.bam} "
    "  -M {output.metrics} > {log} 2>&1 "




rule make_gvcfs_by_chromo:
  input:
    bam="results/mkdup/{sample}.bam",
    bai="results/mkdup/{sample}.bai",
    ref="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna",
    idx="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.dict",
    fai="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna.fai"
  output:
    gvcf="results/gvcf/{chromo}/{sample}.g.vcf.gz",
    idx="results/gvcf/{chromo}/{sample}.g.vcf.gz.tbi",
  conda:
    "Envs/gatk.yaml"
  log:
    "results/logs/make_gvcfs_by_chromo/{chromo}/{sample}.log"
  params:
    java_opts="-Xmx4g",
    hmt=config["params"]["gatk"]["HaplotypeCaller"]["hmm_threads"]
  shell:
    " gatk --java-options \"{params.java_opts}\" HaplotypeCaller "
    " -R {input.ref} "
    " -I {input.bam} "
    " -O {output.gvcf} "
    " -L {wildcards.chromo}    "           
    " --native-pair-hmm-threads {params.hmt} " 
    " -ERC GVCF > {log} 2> {log} "


rule import_genomics_db_by_chromo:
  input:
    gvcfs=expand("results/gvcf/{{chromo}}/{s}.g.vcf.gz", s=SAMPLES)
  output:
    gdb=directory("results/genomics_db/{chromo}")
  conda:
    "Envs/gatk.yaml"
  log:
    "results/logs/import_genomics_db_by_chromo/{chromo}.log"
  params:
    java_opts="-Xmx4g"
  shell:
    " VS=$(for i in {input.gvcfs}; do echo -V $i; done); "  # make a string like -V file1 -V file2
    " gatk --java-options \"-Xmx4g\" GenomicsDBImport "
    "  $VS  "
    "  --genomicsdb-workspace-path {output.gdb} "
    "  -L  {wildcards.chromo} 2> {log} "


rule vcf_from_gdb_by_chromo:
  input:
    gdb="results/genomics_db/{chromo}",
    ref="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna",
    fai="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.fna.fai",
    idx="Reference/ncbi_dataset/data/GCF_018296145.1/GCF_018296145.1_Otsh_v2.0_genomic.dict",
  output:
    vcf="results/chromo_vcfs/{chromo}.vcf.gz",
    idx="results/chromo_vcfs/{chromo}.vcf.gz.tbi",
  conda:
    "Envs/gatk.yaml"
  log:
    "results/logs/vcf_from_gdb_by_chromo/{chromo}.txt"
  shell:
    " gatk --java-options \"-Xmx4g\" GenotypeGVCFs "
    "  -R {input.ref}  "
    "  -V gendb://{input.gdb} "
    "  -O {output.vcf} 2> {log} "


# break out just the indels
rule select_indels:
  input:
    vcf="results/chromo_vcfs/{chromo}.vcf.gz",
    idx="results/chromo_vcfs/{chromo}.vcf.gz.tbi"
  output:
    "results/hard_filtering/indels/{chromo}.vcf.gz"
  conda:
    "Envs/gatk.yaml"
  log:
    "results/logs/select_indels/{chromo}.log"
  shell:
    "gatk SelectVariants "
    " -V {input.vcf} "
    " -select-type INDEL "
    " -O {output} > {log} 2>&1 " 


rule concat_vcfs:
  input:
    vcfs=expand("results/chromo_vcfs/{c}.vcf.gz", c=CHROMOS)
  output:
    vcf="results/vcf/all.vcf.gz"
  conda:
    "Envs/bcftools.yaml"
  log:
    "results/concat_vcfs/all.log"
  shell:
    "bcftools concat -n {input.vcfs} > {output.vcf} 2> {log} "
