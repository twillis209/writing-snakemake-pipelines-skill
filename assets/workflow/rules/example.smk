rule example:
    input:
        unpack(get_fastqs),
        ref="resources/reference.fa",
    output:
        bam="results/example/{sample}.bam",
    log:
        "logs/example/{sample}.log",
    benchmark:
        "benchmarks/example/{sample}.tsv"
    conda:
        "../envs/example.yaml"
    threads: 4
    resources:
        mem_mb=8000,
        runtime=60,
    params:
        extra=lookup(dpath="params/example/extra", within=config, default=""),
        r2=get_r2_arg,
    shell:
        "some_tool {params.extra} --threads {threads} "
        "--ref {input.ref} --r1 {input.r1} "
        "{params.r2} -o {output.bam} &> {log}"


rule mark_done:
    input:
        "results/example/{sample}.bam",
    output:
        touch("results/example/{sample}.done"),
