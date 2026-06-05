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
    params:
        extra=lookup(dpath="params/example/extra", within=config, default=""),
    threads: 4
    resources:
        mem_mb=8000,
        runtime=60,
    conda:
        "../envs/example.yaml"
    shell:
        "some_tool {params.extra} --threads {threads} "
        "--ref {input.ref} --r1 {input.r1} "
        "{input.r2:q} -o {output.bam} &> {log}"


rule mark_done:
    input:
        "results/example/{sample}.bam",
    output:
        touch("results/example/{sample}.done"),
