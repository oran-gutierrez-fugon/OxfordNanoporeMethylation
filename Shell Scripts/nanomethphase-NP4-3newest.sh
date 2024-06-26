#!/bin/bash -v

#Author: Oran Gutierrez Fugon MD PhD, LaSalle Lab, Segal Lab, Integrative Genetics and Genomics graduate group UC Davis

#Although this is structured as a shell script I would recommend each section to be run individually to deal with errors as they arise. Also ran into issues switching between conda env while using screen and some steps are only included to clean up previous attempts and may not be necessary.

#Generally have not seen any part of this pipeline taking up more than 12 GB of memory with 60 cores going at a time but to be safe and respect epigenerate use the this command to limit ram usuage before killing the job at 75GB. Core usage options will vary with resorces available on epigenerate at the time of running.
ulimit -v 75000000

#load modules samtool and minimap
module load samtools
module load minimap2/2.24

#concatenates all basecalled fastqs from all flushes to catcat folder (do not use methylation fastqs) see nanomethphase github
#May want to remove individual flush concat fastq at the end but recommend leave them until you finish the pipeline in case you need to process flushes individualy and then merge the methylation call tsv
#*****WARNING***** input fastq preflush,PF,PF2 folders must be verified with cd one by one not just find/replace replicate name
cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05182023/20230518_1823_3G_PAO36704_d713bcfc/fast5/basecalling/pass/*.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3-.fastq.gz 
cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05192023_PF/20230519_1725_3G_PAO36704_22df49af/fast5/basecalling/pass/*.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3-PF.fastq.gz 
cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05202023_PF2/20230520_1804_3G_PAO36704_e7bf9f77/fast5/basecalling/pass/*.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3-PF2.fastq.gz

cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3-.fastq.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3-PF.fastq.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3-PF2.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3.fastq.gz

#converts fast5 raw files to more efficient blow5 and puts all flushes in same directory. slow5tools was installed in base conda env
#*****WARNING***** input fast5 preflush,PF,PF2 folders must be verified with cd one by one not just find/replace replicate name
conda activate
slow5tools fast5toslow5 -p 60 --to blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05182023/20230518_1823_3G_PAO36704_d713bcfc/fast5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05192023_PF/20230519_1725_3G_PAO36704_22df49af/fast5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05202023_PF2/20230520_1804_3G_PAO36704_e7bf9f77/fast5 -d /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3; echo "It is done" | mail -s "NP4-3 fast5toslow5" ojg333@gmail.com

#merges slow5 dir to 1 single blow5 file
mkdir /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3/blow/
slow5tools merge -t 60 --to blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3  -o /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3/blow/NP4-3cat.blow5

#Cleans up single blow5 files since they are no longer needed
rm /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3/*.slow5 

# activates f5c env and indexes blow5 and fastq
conda activate f5c
f5c index -t 60 --slow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3/blow/NP4-3cat.blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3.fastq.gz

#minimap2 aligment + samtools sam to bam + indexes bam
minimap2 -a -x map-ont -t 60 -2 /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3.fastq.gz | samtools sort -T tmp -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_sorted.bam
samtools index /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_sorted.bam; echo "It is done.." | mail -s "NP4-3 samtools index done" ojg333@gmail.com

#cleans up any previous methylation runs if needed
#rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3-MethylationCall.tsv

#methylation calling with f5c (more efficient program than nanopolish) must include option --pore r10 for r10 chemistry (thanks Logan!)
f5c call-methylation --pore r10 -x hpc-high --meth-out-version 2 --slow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-3/blow/NP4-3cat.blow5 -r /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-3.fastq.gz  -b /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_sorted.bam -g /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3-MethylationCall.tsv; echo "It is done.." | mail -s "NP4-3 f5c call-methylation done" ojg333@gmail.com

#cleans up any previous passed variants vcf to avoid mixed data errors
#cd /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/
#rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/*.*
#rm -r /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/tmp
#rm -r /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/log

#activates clair3 env and loads samtools
conda activate clair3-1.0.4
module load samtools

#NP4-3 variant calling fastqconcats new bam from minimap using hg19 ref. Model is dependent on chemistry and basecaller used (see clair3 and reiro githubs)
run_clair3.sh --bam_fn=/share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_sorted.bam --ref_fn=/share/lasallelab/Oran/dovetail/refgenomes/hg19.fa --output=/share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3 --threads=60 --platform=ont --model_path=/share/lasallelab/Oran/dovetail/luhmes/methylation/clair3model/rerio/clair3_models/r1041_e82_400bps_sup_g615

#filters for passed quality leave unzipped for now since will need to be in bgzip compression format for downstream steps
gunzip -c /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/merge_output.vcf.gz | awk '$1 ~ /^#/ || $7=="PASS"' > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/NP4-3-PassedVariants.vcf

#indexes vcf file in prep for whatshap with bgzip then indexes with tabix. Using HiChIP oj conda env with bgzip and tabix already installed 
conda deactivate
conda activate /share/lasallelab/Oran/dovetail/luhmes/merged/oj
bgzip -i /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/NP4-3-PassedVariants.vcf
tabix -p vcf /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/NP4-3-PassedVariants.vcf.gz

#switches to whatshap conda env
conda deactivate
conda activate /share/lasallelab/Oran/miniconda3/whatshap-env

#phasing with whatshap (reference must be uncompressed and indexed).  Since whatshap is not optimized for multicore this is a good step to do in parallel with other samples on the cluster after running clair3 separately or together with clair3 running for the next sample. May also substitute illumina variant vcf file if available.
whatshap phase --ignore-read-groups --reference /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/NP4-3-whatshap_phased.vcf /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/NP4-3-PassedVariants.vcf.gz /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_sorted.bam

#activates nanomethphase conda env and python step 1 methyl call processor + index. Must be in Nanomethphase folder (Thanks Osman!)
conda deactivate
conda activate /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase/nanometh-environment
cd /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase
python nanomethphase.py methyl_call_processor -mc /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3-MethylationCall.tsv -t 60 | sort -k1,1 -k2,2n -k3,3n | bgzip > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3-MethylationCall.bed.gz && tabix -p bed /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3-MethylationCall.bed.gz

#phases the methylome (the moment you've all been waiting for)
python nanomethphase.py phase --include_indels -b /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_sorted.bam -v /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/clair3/NP4-3-whatshap_phased.vcf -mc /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3-MethylationCall.bed.gz -r /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome -of bam,methylcall,bam2bis -t 50

#aggregates data from both strands (requieres datamash installation)
#use correct file names from previous step, differential methylation in next step does this automatically so can skip
conda activate datamash
sed '1d' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP1_MethylFrequency.tsv | awk -F'\t' '{if ($4=="-") {$2=$2-1;$3=$3-1}; print $1,$2,$3,$5,$6}' OFS='\t' | sort -k1,1 -k2,2n | datamash -g1,2,3 sum 4,5 | awk -F'\t' '{print $0,$5/$4}' OFS='\t' | sed '1i chromosome\tstart\tend\tNumOfAllCalls\tNumOfModCalls\tMethylFreq' > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/NP4-3_aggregated_HP1_MethylFrequency.tsv

sed '1d' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP2_MethylFrequency.tsv | awk -F'\t' '{if ($4=="-") {$2=$2-1;$3=$3-1}; print $1,$2,$3,$5,$6}' OFS='\t' | sort -k1,1 -k2,2n | datamash -g1,2,3 sum 4,5 | awk -F'\t' '{print $0,$5/$4}' OFS='\t' | sed '1i chromosome\tstart\tend\tNumOfAllCalls\tNumOfModCalls\tMethylFreq' > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/NP4-3_aggregated_HP2_MethylFrequency.tsv

#creates directory and cleans up previous dma tries
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA
rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/*.*

#If running script separately will need to go back to nanomethphase conda env
conda deactivate
conda activate /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase/nanometh-environment
cd /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase

#Differential methylation analysis (if you've made it this far, lets go a little farther)
#Check folders and file names match with previous steps but not datamash output since this will aggregate automatically
#see DSS ddocumentation for all options and output file format
#Had to install sys for commandline R in nanomethphase env using R then install.packages("sys") but did not occur in chr15 remaking of env
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP1_MethylFrequency.tsv -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP2_MethylFrequency.tsv -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/ -op DMA

#Visualization for viewing DMA in UCSC genome browser:

#Converts output tsv files to bedgraph 4 column format (can take the read count column instead of methylation if want to make a coverage plot track)
awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $7*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP1_MethylFrequency.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP1_MethylFrequency.bedGraph

awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $7*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP2_MethylFrequency.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP2_MethylFrequency.bedGraph

#For combining replicates from begraphs (Not recommended since can show both replicates overlayed using trackhubs)
#cat replicate1.bedGraph replicate2.bedGraph | sort -k1,1 -k2,2n > combined_sorted.bedGraph

#Changes directory to where bedGraphToBigWig binaries can be run
cd /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed

#sorts bedgraph with bedSort
./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP1_MethylFrequency.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP1_MethylFrequency_sorted.bedGraph

./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP2_MethylFrequency.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP2_MethylFrequency_sorted.bedGraph

#Changes to bigwig format (.bw) for fast viewing in UCSC genome browser
./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP1_MethylFrequency_sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP1_MethylFrequency.bw

./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP2_MethylFrequency_sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/bedgraphs/NP4-3_HP2_MethylFrequency.bw


#Visualization of Differential Methylation Analysis
#Convert space delimited txt callDMR file to tab delimited bedGraph with the percent value being converted to whole numbers by multiplying by 100

#cleans up files from previous attempts
rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR.bedGraph
rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR_Sorted.bedGraph

#Converts output DMA txt files to bedgraph 4 column format (can take the read count column instead of methylation if want to make a coverage plot track)
awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $8*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/DMA_callDMR.txt > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR.bedGraph


cd /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed

#sorts bedgraph with bedSort
./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR_Sorted.bedGraph

#For neurons NP4-3 and NP4-4 since haplotype 1 is maternal but want to standardize with undifferentiated and always have DMA as Paternal vs Maternal this code flips the negative and positive values
awk -F'\t' -v OFS='\t' '{ if ($4 > 0) $4 = -$4; else if ($4 < 0) $4 = -$4; print }' input.bedGraph > output.bedGraph

#Changes to bigwig format (.bw) for fast viewing in UCSC genome browser
./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR_Sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3/DMA/NP4-3_callDMR_Sorted.bw


#Performs DMA with both Neuron replicates comparing Paternal (Case) to Maternal (Control)
#Ran for 5 days took up all cores and did not go past smoothing using:
#python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsMat -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/DMA/ -op DMA

#Performs DMA with both Undifferentiated replicates comparing Paternal (Case) to Maternal (Control)
#python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifMat -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/DMA/ -op DMA

#Performs DMA with both Neurons and Undifferentiated replicates comparing Paternal Neurons(Case) to Paternal Undifferentiated (Control), important for manuscript!
#python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat.tsv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat.tsv -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/ -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/DMAreps/ -op NvUpat

conda activate /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase/nanometh-environment
cd /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase

#Limiting to one core to see if that resolves issue with 2 replicates, it did not
#taskset --cpu-list 3 python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/ -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/ -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/DMA_NvUpat/ -op NvUpat

#Will try what worked before with just one replicate for comparing paternal allele in differentiated vs undifferentiated cells, NP4-3 vs UDP4-3.  Still getting stuck at "Estimating dispersion for each CpG site"
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-3_methylome_NanoMethPhase_HP2_MethylFrequency.tsv -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-3_methylome_NanoMethPhase_HP1_MethylFrequency.tsv -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/DMA_NvUpat/ -op DMA_NvUpat

#Performs DMA with both Neurons and Undifferentiated replicates comparing Maternal Neurons(Case) to Maternal Undifferentiated (Control) (got stuck too)
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsMat -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifMat -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/DMA_NvUmat -op DMA

#Downsampled test, which completed
#python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/DownsampleNP43test.tsv -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/DownsampleNP44test.tsv -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/DMA_NvUpat/ -op DMAtest

#To downsample to just chromosome 15 comparing NP4-3 vs UDP4-3
head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat_chr15.tsv

head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-3_Pat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-3_Pat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-3_Pat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-3_Pat_chr15.tsv

#chr15 reduced DMA finished completed in less than 30 minutes
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat_N3-U3/
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat_chr15.tsv -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-3_Pat_chr15.tsv -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat_N3-U3/ -op DMA_NvUpat_chr15

#To do the same but with the other 2 replicates
head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat_chr15.tsv

head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-2_Pat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-2_Pat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-2_Pat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-2_Pat_chr15.tsv

#This one is just for NP4-4 vs UDP4-2 but now that the first one worked can skip to the next section to do this with both replicates in each cell type
#python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat_chr15.tsv -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-2_Pat_chr15.tsv -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/DMA_NvUpat_N4-U2/ -op N4-U2_DMA_NvUpat_chr15

#Now that we have both chr15 reduced files for all samples we can try to run DMA using the 2 neuron replicates vs both undifferentiated replicates.
#Since it works by looking at all files in a folder we will first need to move chr15 tsv to their separate directories
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsPat
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifPat
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat
mv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-3_Pat_chr15.tsv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsPat/NP4-3_Pat_chr15.tsv
mv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsPat/NP4-4_Pat_chr15.tsv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsPat/NP4-4_Pat_chr15.tsv
mv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-2_Pat_chr15.tsv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifPat/UDP4-2_Pat_chr15.tsv
mv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifPat/UDP4-3_Pat_chr15.tsv /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifPat/UDP4-3_Pat_chr15.tsv

#chr15 specific paternal neurons vs paternal undif using all replicates **completed in about 20 minutes**
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsPat/ -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifPat/ -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat/ -op DMA_NvUpat_chr15_2reps

#can even do this for the paternal vs maternal in each cell type using all replicates
#Must first reduce the maternal alleles to just chromsome 15 this time combining the mv steps
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/

head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsMat/NP4-3_Mat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat/NP4-3_Mat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsMat/NP4-3_Mat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat/NP4-3_Mat_chr15.tsv

head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsMat/NP4-4_Mat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat/NP4-4_Mat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NeuronsMat/NP4-4_Mat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat/NP4-4_Mat_chr15.tsv

head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifMat/UDP4-2_Mat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat/UDP4-2_Mat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifMat/UDP4-2_Mat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat/UDP4-2_Mat_chr15.tsv

head -n 1 /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifMat/UDP4-3_Mat.tsv > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat/UDP4-3_Mat_chr15.tsv 
grep "^chr15" /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UndifMat/UDP4-3_Mat.tsv  >> /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat/UDP4-3_Mat_chr15.tsv

#For neurons
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsPat/ -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat/ -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/ -op DMA_PvMneurons_chr15
#Undif
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifPat/ -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat/ -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/ -op DMA_PvMundif_chr15

#We can do a Dif vs Undif on just the maternal using both replicates
mkdir /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps
python nanomethphase.py dma -c 1,2,4,5,7 -ca /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/NeuronsMat/ -co /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/UndifMat/ -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps -op DMA_NvUmat2reps_chr15
#can even compare neuron pat to undif mat is time allows

#For visualization in UCSC genome browser first creating a bedGraph file from the txt file output
#This time 100% will mean 100% methylation

awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $8*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat2reps/DMA_NvUpat_chr15_2reps_callDMR.txt > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat2reps/DMA_NvUpat_chr15_2reps_callDMR.bedGraph

awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $8*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps/DMA_NvUmat2reps_chr15_callDMR.txt > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps/DMA_NvUmat_chr15_2reps_callDMR.bedGraph

awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $8*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/DMA_PvMneurons_chr15_callDMR.txt > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/DMA_PvMneurons_chr15_2reps_callDMR.bedGraph

awk 'BEGIN {FS="\t"; OFS="\t"}
NR > 1 {print $1, $2, $3, $8*100}' /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/DMA_PvMundif_chr15_callDMR.txt > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/DMA_PvMundif_chr15_2reps_callDMR.bedGraph

#changes directory
cd /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed

#sorts bedgraph with bedSort
./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat2reps/DMA_NvUpat_chr15_2reps_callDMR.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat2reps/DMA_NvUpat_chr15_2reps_callDMR_sorted.bedGraph
./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps/DMA_NvUmat_chr15_2reps_callDMR.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps/DMA_NvUmat_chr15_2reps_callDMR_sorted.bedGraph
./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/DMA_PvMneurons_chr15_2reps_callDMR.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/DMA_PvMneurons_chr15_2reps_callDMR_sorted.bedGraph
./bedSort /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/DMA_PvMundif_chr15_2reps_callDMR.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/DMA_PvMundif_chr15_2reps_callDMR_sorted.bedGraph

#Changes to bigwig format (.bw) for fast viewing in UCSC genome browser
./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat2reps/DMA_NvUpat_chr15_2reps_callDMR_sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUpat2reps/DMA_NvUpat_chr15_2reps_callDMR_sorted.bw
./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps/DMA_NvUmat_chr15_2reps_callDMR_sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_NvUmat2reps/DMA_NvUmat_chr15_2reps_callDMR_sorted.bw
./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/DMA_PvMneurons_chr15_2reps_callDMR_sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMneurons2reps/DMA_PvMneurons_chr15_2reps_callDMR_sorted.bw
./bedGraphToBigWig /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/DMA_PvMundif_chr15_2reps_callDMR_sorted.bedGraph /share/lasallelab/Oran/dovetail/luhmes/methylation/bedToBigBed/hg19.chrom.sizes /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/chr15/DMA_PvMundif2reps/DMA_PvMundif_chr15_2reps_callDMR_sorted.bw


#To view bw files just upload to bioshare, copy link, and create track hub on UCSC genome browser 

# Prints this scary message after the ghost in the shell finishes running so my lazy bones can see it finish from far away.  Bonus points if you can figure out the reference, RIP: Zelda Rubinstein & Heather O'Rourke
echo "
                                                     @@@@@@@@
                                             %&&&&@&          @@@@@(@&@&&#                                                             
                                         /@&%                            .&&@.                                                       
                                      *&@                                      #&&                                                    
                                   .&&                                            /@%                                                 
                                 %&                                                 .&@                                               
                               #&                                                    ..&&                                             
                              &.                                                       ,/&                                            
                            #&                                                          ,.&/                                          
                           @#                                                            ..&#                                         
                          @/                                                              ,.&*                                        
                         &(                                                               .,.@                                        
                        %&                                                                 ,.&&                                       
                        &                                                                  ...&                                       
                       @           @(&&&&&#                @&&&&&@*                        .,.&&                                      
                      (&         ,%&&&&&&&&&@           (&&&&&&&&&&,,                      .,,(&                                      
                      &         .*&&@#&&&&&&&@         #&&&&@&&&&&&&,,                     .,,,&                                      
   .&&&@@@&&@#@&@/   #%         .*&&&&&&&&&&&&         &&&&&&&&&&&&&%,                     .,,.&    #&&@#&&&@@@#&&%.                   
   &.             &#&&           .&&&&&&&&&&&          *&&&&&&&&&&&&,,                     ,,,.&&###         .,,. %@                  
    @% ,            ,&            *.#&&&&&&              &&&&&&&&@&,.                      ,&,             .,,,. %&                   
      &@ ,.        .,                                       &&&                                          ,,,,  @&                     
        &% .,      ,.                                                                                  ,,,,  @@                       
          @* ... .,,,             ,###,       /&&&&&&\      ,###,                                   .,,,,  @&                         
           #& ,,,,,,.          @&&&&&&&&&&&&&&&&&&&&&&&&&&@&&&&&&&&&&&&                           ..,,,. @&                           
             &  .,,.          &%%&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&,%&                        ,,,,, *&                             
              &# ,,(          @#&&&&&&&&&&&&@&&&&&**&&&@&&&&&&&&&&&&&&&.&                      ,,,,,. @%                             
               && ,&            &&&,   '&&&&'          '&&&&'     &&&&#                       ,,.,...&                             
                %@ &                                                                        .*,,,,.,@                     
                 &%&                                                                        ,,,,,.(@                              
                  @&                                                                        ,,..,*&                       
                  ,&                                                                     ..,.,., &&                 
                  /@                                                              ,        ,,,,,@ /@                                  
                  %&                          ,                                   .        ,,,,.,, &(                                 
                  @(                                                              #.       ,,,,,,,, @.                                
                  &.                         .                                    @,.      ,.   .,,. &                                
                  &                          &.                                   &,,            .,,. &                               
                 &@                          #.           .                       *%.,            ,,,  &                              
                 @/                          *,           ,                        &.,.            .,.  &                             
                .&            &             /.,           ,.                       @/,.             ,,,  &                            
               &@           .&             &..           .@                        &,,,            .,,,  @.                          
               .@           ,@              &..          .,&                        @*,,,            ,,,,. &*                         
               &&          ..@              &,.          ,.&                         &,,,,            ,,,,. @.                        
              /&          .,&              .@.,          ,,#.                        &#.,,,            ,,,,, &                        
              @,         .,,@              /@.,          ,,*#                         &.,,,,            ,,,.&%                        
             @@         .,,&               %%,,,         ,,.@                         ,@,,,,..           ,#&                          
            (&         .,,%&               &(,,,        .,,,&                          &%,,,,,,,       @#,                            
            &,        ,,..&                @*,,,        .,,,@                           &/.,.,,.,.%@@.                                
            &&      ,,,,,@*                &,,,.        ,,,.%(                           &,,,,&@/                                     
              #%&#.,,,,,*&                 &,,,,,       ,,,.,&                            &@&                                         
                    &&%,&,                 &*,.,.       ,,,,,&                            .&                                          
                       %@                  &(,,,...   ..,,,,,%&                            *&                                         
                       &%                  %@,    '''''      .&                             &&                                        
                       &&                   &                 &&                            .@                                        
                         &@                @@                  @*                         /&*                                         
                           %%%%&&&&&&&&@&@*                      &@                     &&%                                            
                                                                   (@&&(&&&&&&&&&&&&(%@&&*  

TTTTTT H  H IIIII  SSS     H   H  OOO   U   U   SSS   EEEEE   IIIII  SSS      CCC  L    EEEE     A    N     N
  TT   H  H   I   S    S   H   H O   O  U   U  S   S  E         I   S   S    C     L    E       A A   NN    N
  TT   H  H   I    SS      H   H O   O  U   U   S     E         I    S       C     L    E      A   A  N N   N
  TT   HHHH   I      S     HHHHH O   O  U   U    S    EEE       I      S     C     L    EEE   AAAAAAA N  N  N
  TT   H  H   I       S    H   H O   O  U   U      S  E         I       S    C     L    E     A     A N   N N
  TT   H  H   I   S   S    H   H O   O  U   U  S   S  E         I   S   S    C     L    E     A     A N    NN
  TT   H  H IIIII  SSS     H   H  OOO    UUU    SSS   EEEEE   IIIII  SSS      CCC  LLLL EEEE  A     A N     N
"
