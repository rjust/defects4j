#!/bin/bash
# Gregory Gay (greg@greggay.com)
# Measure whether a fault was not covered, partially covered, or fully covered.

project=$1
fault=$2
trial=$3
source=$4
budget=$5
project_dir=$6
result_dir=$7

# Get range that must be covered
# Basic logic:
# If the line is a new addition, it must be covered.
# If a line is deleted, cover the next non-deleted line after that 
# (this approximates "getting past" the deleted line).
# The "next" line should not be a blank line, solely a block ending (}), or a comment line. 

cat $project_dir"/"$project"/patches/"$fault".src.patch" | awk '
								BEGIN{ line=0; 
									class="";
									needNext=0;
								}
								/\+\+\+/ {
									split($0,parts,"/");
									size=0;
									for(p in parts){
										size++;
									}
									split(parts[size],nameParts," ");
									class=nameParts[1];
								}
								/@@/ {
									split($3,parts,",");
									line=int(substr(parts[1],2,length(parts[1])))-1;
									next;
								}
								/^\s*$/ {
									line++;
									next;
								}
								{ 
									if(class != ""){
										line++;
										if($1=="+"){
											if(needNext==1){
												needNext=0;
											}
											print class "," line;
										}else if($1=="-"){
											needNext=1;
											line--;
										}else{
											if(needNext==1){
												if($1 == "}"){
													if($2 != ""){
														print class "," line;
														needNext=0;
													}
												}else if(($1 !~ /\/*,*\//) && ($1 !~ /\/*\*/)){
													print class "," line;
													needNext=0;
												}
											}
										}
									}
								}' >> affectedlines.csv

# Check coverage file for desired lines.
# If a line does not exist in the coverage file, it is ignored for coverage purposes.  
cat affectedlines.csv

score=`cat $7"/suites/"$project"_"$fault"/"$budget"/"$project"/"$source"/"$trial"/coverage_log/"$project"/"$source"/"$fault"b."$trial".xml" | awk -v InFile="affectedlines.csv" '
	BEGIN{
		numLines=0;
		# Read in the list of lines.
		while(getline x < InFile){
			lines[x]=-1; # -1 means never seen, -2 means covered, -3 means not covered. 
			numLines++;
		}
		close(InFile);
		class="";
	}
	# Get the filename of the class, to compare with above.
	/<class name/ {
		class=$3;
		split(class,parts,"\"");
		split(parts[2],dirs,"/");
		size=0;
		for(d in dirs){
			size++;	
		}
		class=dirs[size];
	}
	# Get the line number and see if it is covered.
	/<line number/{
		split($2,parts,"\"");
		num=parts[2];
		# How many times has it been hit?
		if(lines[class","num]==-1){
			split($3,hits,"\"");
			if(hits[2] > 0){
				lines[class","num]=-2;
			}else{
				lines[class","num]=-3;
			}
		}
	}

	END{
		# Tally up the coverage score.
		covered = 0;
		total = 0;
		for(l in lines){
			if(lines[l] < -1){
				total++;
				if(lines[l] == -2)
					covered++;
			}
		}
		print covered "," total "," (covered/total);
	}
'`

# Output to log file.

log_file=$result_dir"/suites/fault_coverage.csv"

if [ -a $log_file ]; then
	echo $project","$fault","$trial","$budget","$source","$score >> $log_file
else
	echo "# Project, Fault, Trial, Search Budget, Suite Source, Covered Lines, Number of Lines to Cover, Fault Coverage" >> $log_file
	echo $project","$fault","$trial","$budget","$source","$score >> $log_file
fi

rm affectedlines.csv
