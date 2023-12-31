#!/bin/bash -v

#load modules samtool and minimap
module load samtools
module load minimap2/2.24

#minimap alignment to sam UDP4-2
minimap2 -ax map-ont /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa.gz /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/UDP4-2.fastq.gz > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2.sam

#Converts back into bam, sorts and indexes
samtools view -bS /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2.sam > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2.bam

samtools sort -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2_sorted.bam /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2.bam

samtools index /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2_sorted.bam

#Removes intermediate files
rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2.sam /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2.bam

#converts fast5 to more efficient slow5 and puts all slow5 flushes in same directory. Installed slow5 tools in conda base env (save more space using --to blow5 binary format)
#*****warning***** input fast5,PF,PF2 folders must be verified one by one not just replace replicate name - this is main reason for skipped read errors in downstream methylation calling with f5c
conda activate
slow5tools fast5toslow5 -p 60 --to blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_UDP4-2_05032023/20230503_1715_2G_PAM05619_2a82e598/fast5/ /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_UDP4-2_05042023_PF/20230504_1405_2G_PAM05619_b1291f1b/fast5/ /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_UDP4-2_05052023_PF2/20230505_1817_2G_PAM05619_b73e9ab9/fast5/ -d /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2; echo "UDP4-2 fast5toslow5 done body" | mail -s "UDP4-2 fast5toslow5 done title" ojg333@gmail.com

#merges slow5 dir to 1 single blow5 file
slow5tools merge -t 60 --to blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2  -o /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2/blow/UDP4-2cat.blow5

#Cleans up single slow5 or blow5 files
rm /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2/*.slow5
mv /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2/blow5/UDP4-2cat.blow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2/UDP4-2cat.blow5

# activates f5c amd indexes blow5 and fastq, not interchangable with nanopolish index
conda activate f5c
f5c index -t 60 --iop 60 -d /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_UDP4-2_05032023/20230503_1715_2G_PAM05619_2a82e598/fast5/ -d /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_UDP4-2_05042023_PF/20230504_1405_2G_PAM05619_b1291f1b/fast5/ -d /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/PROM0151_LaSalle_UDP4-2_05052023_PF2/20230505_1817_2G_PAM05619_b73e9ab9/fast5/ /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/UDP4-2.fastq.gz

#cleans up any previous methylation runs
rm /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2-MethylationCall.tsv

#methylation calling with f5c (more efficient program than nanopolish) must include option --pore r10 for r10 chemistry (thanks Logan!)
f5c call-methylation --pore r10 -x hpc-high --meth-out-version 2 --skip-unreadable=no --slow5 /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/slow5/UDP4-2/blow/UDP4-2cat.blow5 -r /share/lasallelab/Oran/dovetail/luhmes/nanoRAW/catcat/UDP4-2.fastq.gz  -b /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2_sorted.bam -g /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2-MethylationCall.tsv; echo "UDP4-2 f5c call-methylation done" | mail -s "UDP4-2 f5c call-methylation done" ojg333@gmail.com


#cleans up any previous passed variants vcf to avoid downstream errors
cd /share/lasallelab/Oran/dovetail/luhmes/methylation/concatenated/UDP4-2/clair3/
rm /share/lasallelab/Oran/dovetail/luhmes/methylation/concatenated/UDP4-2/clair3/*.*
rm -r /share/lasallelab/Oran/dovetail/luhmes/methylation/concatenated/UDP4-2/clair3/tmp
rm -r /share/lasallelab/Oran/dovetail/luhmes/methylation/concatenated/UDP4-2/clair3/log


#activates clair3 env and loads samtools
conda activate clair3-1.0.4
module load samtools

#UDP4-2 variant calling fastqconcats new bam from minimap using hg19 ref
run_clair3.sh --bam_fn=/share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2_sorted.bam --ref_fn=/share/lasallelab/Oran/dovetail/refgenomes/hg19.fa --output=/share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3 --threads=40 --platform=ont --model_path=/software/anaconda3/23.1.0/lssc0-linux/envs/clair3-1.0.4/bin/models/r941_prom_sup_g5014

#filters for passed quality
gunzip -c /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3/merge_output.vcf.gz | awk '$1 ~ /^#/ || $7=="PASS"' > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3/UDP4-2-PassedVariants.vcf

#indexes vcf file in prep for whatshap with bgzip then tabix
conda deactivate
conda activate /share/lasallelab/Oran/dovetail/luhmes/merged/oj
bgzip -i /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3/UDP4-2-PassedVariants.vcf
tabix -p vcf /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3/UDP4-2-PassedVariants.vcf.gz

#activates whatshap env
conda deactivate
conda activate /share/lasallelab/Oran/miniconda3/whatshap-env

#phasing with whatshap (reference must be uncompressed and indexed)
whatshap phase --ignore-read-groups --reference /share/lasallelab/Oran/dovetail/refgenomes/hg19.fa -o /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3/UDP4-2-whatshap_phased.vcf /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2/clair3/UDP4-2-PassedVariants.vcf.gz /share/lasallelab/Oran/dovetail/luhmes/methylation/fastqconcats/UDP4-2x-cat_sorted.bam

# nanomethphase conda env and python step 1 methyl call processor
conda deactivate
conda activate /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase/nanometh-environment
cd /share/lasallelab/Oran/test_nanomethphase/NanoMethPhase
python nanomethphase.py methyl_call_processor -mc /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2-MethylationCall.tsv -t 20 | sort -k1,1 -k2,2n -k3,3n | bgzip > /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2-MethylationCall.bed.gz && tabix -p bed /share/lasallelab/Oran/dovetail/luhmes/methylation/phasing/UDP4-2-MethylationCall.bed.gz


# Prints this scary message after the ghost in the shell finishes running.  RIP: Zelda Rubinstein & Heather O'Rourke
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
