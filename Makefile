MOTHUR = code/mothur/mothur
REFS = data/references
BASIC_STEM = data/mothur/epiphytes.trim.contigs.good.unique.good.filter.unique.precluster
FIGS = results/figures
TABLES = results/tables
PROC = data/process
FINAL = submission/
MOTHUR = code/mothur/mothur

# Obtained the Linux version of mothur (v1.39.5) from the mothur GitHub repository
$(MOTHUR) :
	wget --no-check-certificate https://github.com/mothur/mothur/releases/download/v1.39.5/Mothur.linux_64.zip
	unzip Mothur.linux_64.zip
	mv mothur code/
	rm Mothur.linux_64.zip
	rm -rf __MACOSX

#########################################################################################
#
# Part 1: Create the reference files
#
# 	We will need several reference files to complete the analyses including the
# SILVA reference alignment and taxonomy. Aa we are analyzing both Bacteria and
# Archaea we need to optimize the procedure described on the mothur blog
# (http://blog.mothur.org/2018/01/10/SILVA-v132-reference-files/).
#
#########################################################################################

# We want the latest greatest reference alignment and the SILVA reference
# alignment is the best reference alignment on the market. We will use the 
# version 132. The curation of the reference files to make them compatible with 
# mothur is described at http://blog.mothur.org/2018/01/10/SILVA-v132-reference-files/
# As we are using the primers from the Earth Microbiome Project that are targeting
# both Bacteria and Archaea (http://www.earthmicrobiome.org/protocols-and-standards/16s/)
# we need to modify the procedure described at
# http://blog.mothur.org/2018/01/10/SILVA-v132-reference-files/
# as this approach is removing shorter archeal sequences.
# 
# The SILVA Release 132 was downloaded from 
# https://www.arb-silva.de/fileadmin/arb_web_db/release_132/ARB_files/SILVA_132_SSURef_NR99_13_12_17_opt.arb.gz
# opened with ARB and exported to silva.full_v132.fasta file as described at
# http://blog.mothur.org/2018/01/10/SILVA-v132-reference-files/ uder the 
# section Getting the data in and out of the ARB database. A total of 629,211
# sequences were exported.

# Screening the sequences
$(REFS)/silva.full_v132.fasta\
$(REFS)/silva.nr_v132.align\
$(REFS)/silva.nr_v132.full : $(MOTHUR)\
                             ~/silva.full_v132/silva.full_v132.fasta
	cp ~/silva.full_v132/silva.full_v132.fasta $(REFS)/silva.full_v132.fasta
	$(MOTHUR) "#screen.seqs(fasta=$(REFS)/silva.full_v132.fasta, start=1044, end=43116, maxambig=5, processors=16);\
	pcr.seqs(start=1044, end=43116, keepdots=T);\
	degap.seqs();\
	unique.seqs()"
        # Identify the unique sequences without regard to their alignment
	grep ">" $(REFS)/silva.full_v132.good.pcr.ng.unique.fasta | cut -f 1 | cut -c 2- > $(REFS)/silva.full_v132.good.pcr.ng.unique.accnos
        # Get the unique sequences without regard to their alignment
	$(MOTHUR) "#get.seqs(fasta=$(REFS)/silva.full_v132.good.pcr.fasta, accnos=$(REFS)/silva.full_v132.good.pcr.ng.unique.accnos)"
        # Generate alignment file
	mv $(REFS)/silva.full_v132.good.pcr.pick.fasta $(REFS)/silva.nr_v132.align
        # Generate taxonomy file
	grep '>' $(REFS)/silva.nr_v132.align | cut -f 1,3 | cut -f 2 -d '>' > $(REFS)/silva.nr_v132.full

# Formatting the taxonomy files
$(REFS)/silva.nr_v132.tax : code/format_taxonomy.R\
                            $(REFS)/silva.nr_v132.full
	wget https://www.arb-silva.de/fileadmin/silva_databases/current/Exports/taxonomy/tax_slv_ssu_132.txt
	mv tax_slv_ssu_132.txt $(REFS)/tax_slv_ssu_132.txt
	R -e "source('code/format_taxonomy.R')"
	mv $(REFS)/silva.full_v132.tax $(REFS)/silva.nr_v132.tax

# Trimming the database to the region of interest (V4 region)
$(REFS)/silva.nr_v132.pcr.align\
$(REFS)/silva.nr_v132.pcr.unique.align : $(REFS)/silva.nr_v132.align\
                                         $(MOTHUR)\
                                         $(BASIC_STEM).pick.pick.pick.error.summary
	$(MOTHUR) "#pcr.seqs(fasta=$(REFS)/silva.nr_v132.align, start=11894, end=25319, keepdots=F, processors=16); unique.seqs()"

#########################################################################################
#
# Part 2: Run data through mothur and get the sequencing error
#
# 	Process fastq data through the generation of files that will be used in the
# overall analysis.
#
#########################################################################################
data/raw/file_names.txt\
data/raw/*.fastq.gz : data/raw/epiphytes.files
	(cut -f 2 data/raw/epiphytes.files; cut -f 3 data/raw/epiphytes.files) | cat > data/raw/names_file.txt
	xargs -I % --arg-file=data/raw/names_file.txt cp ~/raw/together/% -t data/raw/	

# Here we go from the raw fastq files and the files file to generate a fasta,
# taxonomy, and count_table file that has had the chimeras removed as well as
# any non bacterial sequences.
# The raw data (.fastq files) should be locateted in data/raw/

# Edit code/get_good_seqs.batch to include the proper name of your *files file
# Add a primer.oligos file containing the sequences of the gene speciic primers
$(BASIC_STEM).denovo.vsearch.pick.pick.count_table\
$(BASIC_STEM).pick.pick.fasta\
$(BASIC_STEM).pick.nr_v132.wang.pick.taxonomy\
$(BASIC_STEM).pick.nr_v132.wang.tax.summary : code/get_good_seqs.batch\
                                              data/raw/epiphytes.files\
                                              data/raw/primer.oligos\
                                              data/raw/*.fastq.gz\
                                              $(REFS)/silva.nr_v132.pcr.align\
                                              $(REFS)/silva.nr_v132.pcr.unique.align\
                                              $(REFS)/silva.nr_v132.tax\
                                              $(MOTHUR)
	$(MOTHUR) code/get_good_seqs.batch
	rm data/mothur/*.map

# Create a summary.txt file to check that all went alright throughout the code/get_good_seqs.batch
data/summary.txt : data/references/silva.nr_v132.pcr.align\
                   data/references/silva.nr_v132.pcr.unique.align\
                   $(BASIC_STEM).denovo.vsearch.pick.pick.count_table\
                   data/mothur/epiphytes.trim.contigs.fasta\
                   data/mothur/epiphytes.trim.contigs.good.unique.fasta\
                   data/mothur/epiphytes.trim.contigs.good.count_table\
                   data/mothur/epiphytes.trim.contigs.good.unique.align\
                   data/mothur/epiphytes.trim.contigs.good.count_table\
                   data/mothur/epiphytes.trim.contigs.good.unique.good.align\
                   data/mothur/epiphytes.trim.contigs.good.good.count_table\
                   $(BASIC_STEM).pick.fasta\
                   $(BASIC_STEM).denovo.vsearch.pick.count_table\
                   $(BASIC_STEM).pick.pick.fasta\
                   $(MOTHUR)
	$(MOTHUR) code/get_summary.batch

# Here we go from the good sequences and generate a shared file and a
# cons.taxonomy file based on OTU data.

# Edit code/get_shared_otus.batch to include the proper root name of your files file.
# Edit code/get_shared_otus.batch to include the proper group names to remove.

$(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.shared\
$(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.0.03.cons.taxonomy : code/get_shared_otus.batch\
                                                                       $(BASIC_STEM).denovo.vsearch.pick.pick.count_table\
                                                                       $(BASIC_STEM).pick.pick.fasta\
                                                                       $(BASIC_STEM).pick.nr_v132.wang.pick.taxonomy\
                                                                       $(MOTHUR)\
                                                                       data/summary.txt
	$(MOTHUR) code/get_shared_otus.batch
	rm $(BASIC_STEM).denovo.vsearch.pick.pick.pick.count_table
	rm $(BASIC_STEM).pick.pick.pick.fasta
	rm $(BASIC_STEM).pick.nr_v132.wang.pick.pick.taxonomy

# Now we want to get the sequencing error as seen in the mock community samples.

# Edit code/get_error.batch to include the proper root name of your files file.
# Edit code/get_error.batch to include the proper group names for your mocks.

$(BASIC_STEM).pick.pick.pick.error.summary : code/get_error.batch\
                                             $(BASIC_STEM).denovo.vsearch.pick.pick.count_table\
                                             $(BASIC_STEM).pick.pick.fasta\
                                             $(BASIC_STEM).pick.nr_v132.wang.pick.taxonomy\
                                             ~/zymo/zymo.fasta\
                                             $(MOTHUR)\
                                             $(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.0.03.cons.taxonomy
	cp ~/zymo/zymo.fasta $(REFS)/zymo.fasta
	$(MOTHUR) code/get_error.batch

#########################################################################################
#
# Part 3: Figure and table generation
#
# 	Run scripts to generate figures and tables
#
#########################################################################################

# Generate a community composition barplot
results/figures/community_barplot.jpg : code/plot_community_barplot.R\
                                        $(BASIC_STEM).pick.nr_v132.wang.tax.summary
	R -e "source('code/plot_community_barplot.R')"

# Generate data to plot NMDS ordination
# $(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.thetayc.0.03.lt.av.lt.ave.nmds.axes : $(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.shared\
#                                                                                        $(MOTHUR)
#	$(MOTHUR) code/get_nmds_data.batch

# Construct NMDS png file
#results/figures/nmds_figure.png : code/plot_nmds.R\
#                                  $(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.thetayc.0.03.lt.av.lt.ave.nmds.axes
#	R -e "source('code/plot_nmds.R'); plot_nmds('$(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.thetayc.0.03.lt.ave.nmds.axes')"

#########################################################################################
#
# Part 4: Combaine all together
#
# 	Render the manuscript
#
#########################################################################################

# $(FINAL)/manuscript.% : results/figures/nmds_figure.png\
#                        $(BASIC_STEM).pick.pick.pick.opti_mcc.unique_list.shared\
#                        $(FINAL)/mbio.csl\
#                        $(FINAL)/references.bib\
#                        $(FINAL)/manuscript.Rmd
#	R -e 'render("$(FINAL)/manuscript.Rmd", clean=FALSE)'
#	mv $(FINAL)/manuscript.knit.md submission/manuscript.md
#	rm $(FINAL)/manuscript.utf8.md

# write.paper : results/figures/nmds_figure.png\
#              $(FINAL)/manuscript.Rmd $(FINAL)/manuscript.md\
#	$(FINAL)/manuscript.tex $(FINAL)/manuscript.pdf

# Cleaning
.PHONY: clean
clean :
	rm -f my_job.qsub.* || true
	rm -f data/references/* || true
	rm -f data/mothur/* || true
	rm -f data/summary.txt || true
	rm -f data/raw/*.fastq.gz || true
	rm -f data/raw/file_names.txt || true
	rm -rf code/mothur || true
	rm -f results/figures/* || true
