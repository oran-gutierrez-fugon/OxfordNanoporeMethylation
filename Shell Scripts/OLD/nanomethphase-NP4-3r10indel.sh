#!/bin/bash -v

#Author: Oran Gutierrez Fugon MD PhD, LaSalle Lab, Segal Lab, Integrative Genetics and Genomics graduate group UC Davis

#Although this is structured as a shell script I would recommend each section to be run individually to deal with errors as they arise. Also ran into issues switching between conda env and some steps are only included to clean up previous attempts.

#load modules samtool and minimap
module load samtools
module load minimap2/2.24

#concatenates all basecalled fastqs from all flushes to catcat folder (do not use methylation fastqs) see nanomethphase github
#May want to remove individual flush concat fastq at the end but recommend leave them until you finish the pipeline in case you need to process flushes individualy and then merge the methylation call tsv
#*****WARNING***** input fastq preflush,PF,PF2 folders must be verified with cd one by one not just find/replace replicate name
cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05182023/20230518_1823_3G_PAO36704_d713bcfc/fast5/basecalling/pass/*.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4-.fastq.gz 
cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05192023_PF/20230519_1725_3G_PAO36704_22df49af/fast5/basecalling/pass/*.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4-PF.fastq.gz 
cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05202023_PF2/20230520_1804_3G_PAO36704_e7bf9f77/fast5/basecalling/pass/*.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4-PF2.fastq.gz

cat /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4-.fastq.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4-PF.fastq.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4-PF2.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4.fastq.gz

#converts fast5 raw files to more efficient blow5 and puts all flushes in same directory. slow5tools was installed in base conda env
#*****WARNING***** input fast5 preflush,PF,PF2 folders must be verified with cd one by one not just find/replace replicate name
conda activate
slow5tools fast5toslow5 -p 60 --to blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05182023/20230518_1823_3G_PAO36704_d713bcfc/fast5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05192023_PF/20230519_1725_3G_PAO36704_22df49af/fast5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_NP4_4_05202023_PF2/20230520_1804_3G_PAO36704_e7bf9f77/fast5 -d /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4; echo "It is done" | mail -s "NP4-4 fast5toslow5" ojg333@gmail.com

#merges slow5 dir to 1 single blow5 file
mkdir /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4/blow/
slow5tools merge -t 60 --to blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4  -o /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4/blow/NP4-4cat.blow5

#Cleans up single blow5 files since they are no longer needed
rm /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4/*.slow5 

# activates f5c env and indexes blow5 and fastq
conda activate f5c
f5c index -t 60 --slow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4/blow/NP4-4cat.blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4.fastq.gz

#minimap2 aligment + samtools sam to bam + indexes bam
minimap2 -a -x map-ont -t 60 -2 /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4.fastq.gz | samtools sort -T tmp -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_sorted.bam
samtools index /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_sorted.bam; echo "NP4-4 samtools index done title" | mail -s "NP4-4 samtools index done content" ojg333@gmail.com

#cleans up any previous methylation runs if needed
#rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4-MethylationCall.tsv

#methylation calling with f5c (more efficient program than nanopolish) must include option --pore r10 for r10 chemistry (thanks Logan!)
f5c call-methylation --pore r10 -x hpc-high --meth-out-version 2 --slow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/NP4-4/blow/NP4-4cat.blow5 -r /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/NP4-4.fastq.gz  -b /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_sorted.bam -g /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4-MethylationCall.tsv; echo "NP4-4 f5c call-methylation done" | mail -s "NP4-4 f5c call-methylation done" ojg333@gmail.com

#cleans up any previous passed variants vcf to avoid mixed data errors
#cd /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/
#rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/*.*
#rm -r /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/tmp
#rm -r /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/log

#activates clair3 env and loads samtools
conda activate clair3-1.0.4
module load samtools

#NP4-4 variant calling fastqconcats new bam from minimap using hg19 ref. Model is dependent on chemistry and basecaller used (see clair3 and reiro githubs)
run_clair3.sh --bam_fn=/share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_sorted.bam --ref_fn=/share/lasallelab/Oran/dovetail/refgenomes/hg19.fa --output=/share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3 --threads=60 --platform=ont --model_path=/share/lasallelab/Oran/dovetail/luhmes/methylation/clair3model/rerio/clair3_models/r1041_e82_400bps_sup_g615

#filters for passed quality leave unzipped for now since will need to be in bgzip compression format for downstream steps
gunzip -c /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/merge_output.vcf.gz | awk '$1 ~ /^#/ || $7=="PASS"' > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/NP4-4-PassedVariants.vcf

#indexes vcf file in prep for whatshap with bgzip then indexes with tabix. Using HiChIP oj conda env with bgzip and tabix already installed 
conda deactivate
conda activate /share/lasallelab/Oran/dovetail/luhmes/merged/oj
bgzip -i /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/NP4-4-PassedVariants.vcf
tabix -p vcf /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/NP4-4-PassedVariants.vcf.gz

#switches to whatshap conda env
conda deactivate
conda activate /share/lasallelab/Oran/miniconda3/whatshap-env

#phasing with whatshap (reference must be uncompressed and indexed).  Since whatshap is not optimized for multicore this is a good step to do in parallel with other samples on the cluster after running clair3 separately or together with clair3 running for the next sample. May also substitute illumina variant vcf file if available
whatshap phase --ignore-read-groups --indels --reference /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/NP4-4-indel_phased.vcf /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/NP4-4-PassedVariants.vcf.gz /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_sorted.bam

#activates nanomethphase conda env and python step 1 methyl call processor (Thanks Osman!)
conda deactivate
conda activate /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase/nanometh-environment
cd /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase
python nanomethphase.py methyl_call_processor -mc /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4-MethylationCall.tsv -t 60 | sort -k1,1 -k2,2n -k3,3n | bgzip > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4-MethylationCall.bed.gz && tabix -p bed /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4-MethylationCall.bed.gz

#phases the methylome (the moment you've all been waiting for)
python nanomethphase.py phase --include_indels -b /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_sorted.bam -v /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/clair3/NP4-4-indel_phased.vcf -mc /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4-MethylationCall.bed.gz -r /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4_methylome -of bam,methylcall,bam2bis -t 60

#aggregates data from both strands (requieres datamash installation)
#use correct file names from previous step
sed '1d' NP4-4_methylome_HP1_MethylFrequency.tsv | awk -F'\t' '{if ($4=="-") {$2=$2-1;$3=$3-1}; print $1,$2,$3,$5,$6}' OFS='\t' | sort -k1,1 -k2,2n | datamash -g1,2,3 sum 4,5 | awk -F'\t' '{print $0,$5/$4}' OFS='\t' | sed '1i chromosome\tstart\tend\tNumOfAllCalls\tNumOfModCalls\tMethylFreq' > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/NP4-4/HP1_MethylFrequency.tsv




# Prints this scary message after the ghost in the shell finishes running.  Bonus points if you get the reference, RIP: Zelda Rubinstein & Heather O'Rourke
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
