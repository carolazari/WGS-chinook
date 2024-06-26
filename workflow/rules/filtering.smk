rule select_calls:
    input:
        ref="resources/genome.fasta",
        vcf="genotyped/all.vcf.gz",
    output:
        vcf=temp("filtered/all.{vartype}.vcf.gz"),
    params:
        extra=get_vartype_arg,
    log:
        "logs/gatk/selectvariants/{vartype}.log",
    wrapper:
        "0.59.0/bio/gatk/selectvariants"


rule hard_filter_calls:
    input:
        ref="resources/genome.fasta",
        vcf="filtered/all.{vartype}.vcf.gz",
    output:
        vcf=temp("filtered/all.{vartype}.hardfiltered.vcf.gz"),
    params:
        filters=get_filter,
    log:
        "logs/gatk/variantfiltration/{vartype}.log",
    wrapper:
        "0.59.2/bio/gatk/variantfiltration"


rule recalibrate_calls:
    input:
        vcf="filtered/all.{vartype}.vcf.gz",
    output:
        vcf=temp("filtered/all.{vartype}.recalibrated.vcf.gz"),
    params:
        extra=config["params"]["gatk"]["VariantRecalibrator"],
    log:
        "logs/gatk/variantrecalibrator/{vartype}.log",
    wrapper:
        "0.59.2/bio/gatk/variantrecalibrator"


rule merge_calls:
    input:
        vcfs=expand(
            "filtered/all.{vartype}.{filtertype}.vcf.gz",
            vartype=["snvs", "indels"],
            filtertype="recalibrated"
            if config["filtering"]["vqsr"]
            else "hardfiltered",
        ),
    output:
        vcf="filtered/all.vcf.gz",
    log:
        "logs/picard/merge-filtered.log",
    wrapper:
        "0.59.2/bio/picard/mergevcfs"