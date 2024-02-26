#!/bin/bash
if [[ $(find ../ -maxdepth 1 -type d -name "fast5") == "../fast5" ]] ; then
    echo "
    There is a folder called 'fast5', it should be a merged folder from fast5_*."
else
    echo "
    There is no folder called 'fast5', please merge folder fast5_* to 'fast5'
    , and run guppy_basecaler again!"
    exit -1
fi

if [[ $(find ../fast5/ -maxdepth 1 -type d -name "guppy") == "../fast5/guppy" ]] ; then
    echo "
    There is a folder called 'fast5/guppy', it should be created by guppy_basecaller."
    passpath="../fast5/guppy/pass/"
else
    echo "
    There is no folder called 'fast5/guppy', please finish basecalling 
    by running guppy_basecaller before this bash script."
    exit -1
fi


source activate MINDS
echo "
    centrifuge version:" $(centrifuge --version| grep "version 1" | cut -f 3 -d " ")
echo "
    <"$(date -Iminutes)">"

indexline=$(cut settings_centrifuge.csv -f 1 -d "," | grep -n $(cat settings_centrifuge.csv | grep "Index" | cut -f 2 -d ",") | cut -f 1 -d ":")
indexname=$(tail -n +$indexline settings_centrifuge.csv | head -n 1|cut -f 2 -d ",")
indexpath=$(tail -n +$indexline settings_centrifuge.csv | head -n 1|cut -f 3 -d ",")
serialbarcode=$(grep "Is barcode" settings_centrifuge.csv | cut -f 2 -d ",")


echo ""
if [[ $(find ${indexpath} -maxdepth 1 -type f -name "${indexname}*" ) ]] ; then
    echo "
    Using ${indexpath}${indexname}.*.cf as index file.
    "
else
    echo "
    There are no index file '${indexpath}${indexname}.*.cf.'
    Please check file 'settings_centrifuge.csv'"
fi

ls $(echo $indexpath$indexname"*")

echo -ne "* ${indexname} " >> log1.org
echo -ne "* ${indexname} " >> log2.org

date -Iminute >> log1.org
date -Iminute >> log2.org

echo "centrifuge version:" $(centrifuge --version| grep "version 1" | cut -f 3 -d " ") >> log1.org
echo "centrifuge version:" $(centrifuge --version| grep "version 1" | cut -f 3 -d " ") >> log2.org
mkdir cnfr_result
mkdir cnfr_report

## centrifuge funtion
fcentrifuge() {
    barcodeno=barcode$i
    fastq=$barcodeno".fastq"
    # check if barcode$i folder exist
    echo "** ${barcodeno}" >> log1.org
    echo "** ${barcodeno}" >> log2.org
    if [[ $(find $passpath -maxdepth 1 -type d -name barcode$i) = ${passpath}${barcodeno} ]] ; then
	echo "
	Folder barcode$i exist."
	# check if merged file
	#echo ${passpath}${barcodeno}/
	#echo $fastq
	find ${passpath}${barcodeno}/ -maxdepth 1 -type d -name $fastq
	if [[ $(find ${passpath}${barcodeno} -maxdepth 1 -type f -name $fastq) = "${passpath}${barcodeno}/${fastq}" ]] ; then
	    echo "
	${fastq} exist."
	    
	else
	    echo "
	There is no ${fastq}. Now combining ${barcodeno}/fastq_*.fastq to ${barcodeno}/${fastq}"
	    cat ${passpath}${barcodeno}/fastq_*.fastq > ${passpath}${barcodeno}/${fastq}
	fi

	echo "Now, Identify ${fastq}..."
	
	# centrifuge -x
	nohup centrifuge -x ${indexpath}${indexname} -q ${passpath}${barcodeno}/${fastq} -t -p 8 -S ./cnfr_result/${indexname}_${barcodeno}_result.txt --report-file ./cnfr_report/${indexname}_${barcodeno}_report.txt --mm --exclude-taxids 0 1>>log1.org 2>>log2.org
	
    else
	echo "
	There is no folder called barcode$i, please check 'settings_centrifuge.csv'."
	echo "There is no folder called barcode$i, please check =settings_centrifuge.csv=." >> log2.org
    fi

    
    # find $passpath -maxdepth 1 -type d -name barcode$i
    # ls ../fast5/guppy/pass/ | grep barcode$i
}

# combine result.txt
combine() {
    echo "
    Now combining ./cnfr_result/${indexname}_barcode${i}_result.txt"
    tail -n +2 ./cnfr_result/${indexname}_barcode${i}_result.txt > ./combined_result/tmp1
    j=$(wc -l ./combined_result/tmp1 | cut --delimiter=" " -f 1)
    # echo $j
    echo "barcode"$i > ./combined_result/tmp2
    for k in $(seq 2 $j)
    do
        echo "barcode"$i >> ./combined_result/tmp2
    done
    paste ./combined_result/tmp1 ./combined_result/tmp2 >> ./combined_result/$(date -I)_merge_result.txt
    rm ./combined_result/tmp1 ./combined_result/tmp2
}

#echo $serialbarcode
if [ $serialbarcode = "Yes" ] ; then
    echo "
    Is barcode serial?" $serialbarcode

    bf=$(cat settings_centrifuge.csv | grep "barcode from" | cut -f 2 -d ",")
    bt=$(cat settings_centrifuge.csv | grep "barcode to" | cut -f 2 -d ",")
    for i in $(seq -f "%02g" $bf $bt)
    do
	fcentrifuge
    done
# make a column title
    for i in $(seq -f "%02g" $bf $bt)
    do    
	if [[ $(find ./cnfr_result/ -maxdepth 1 -type f -name ${indexname}_barcode${i}_result.txt) = ./cnfr_result/${indexname}_barcode${i}_result.txt ]] ; then
	    mkdir combined_result  
	    head -n 1 ./cnfr_result/${indexname}_barcode${i}_result.txt > ./combined_result/tmp1
	    echo barcode > ./combined_result/tmp2
	    paste ./combined_result/tmp1 ./combined_result/tmp2 > ./combined_result/$(date -I)_merge_result.txt
	    
	    break
	else
	    continue
	fi	
    done

    for i in $(seq -f "%02g" $bf $bt)
    do
	if [[ $(find ./cnfr_result/ -maxdepth 1 -type f -name ${indexname}_barcode${i}_result.txt) = ./cnfr_result/${indexname}_barcode${i}_result.txt ]] ; then		    
	    combine
	    
	else
	    echo "There is no ./cnfr_result/${indexname}_barcode${i}_result.txt."
	    continue
	fi
    done

    
elif [ $serialbarcode = 'No' ] ; then
    echo "
    Is barcode serial? ${serialbarcode}"
    echo "
    Program will process according barcode.txt." 

    barcodefilepath=$(grep "barcode reference" settings_centrifuge.csv | cut -f 3 -d ",")
    barcodefile=$(grep "barcode reference" settings_centrifuge.csv | cut -f 2 -d ",")
    for i in $(cat $barcodefilepath$barcodefile)
    do
	fcentrifuge
    done

    for i in $(cat $barcodefilepath$barcodefile)
    do    
	if [[ $(find ./cnfr_result/ -maxdepth 1 -type f -name ${indexname}_barcode${i}_result.txt) = ./cnfr_result/${indexname}_barcode${i}_result.txt ]] ; then
	    mkdir combined_result  
	    head -n 1 ./cnfr_result/${indexname}_barcode${i}_result.txt > ./combined_result/tmp1
	    echo barcode > ./combined_result/tmp2
	    paste ./combined_result/tmp1 ./combined_result/tmp2 > ./combined_result/$(date -I)_merge_result.txt
	    
	    break
	else
	    continue
	fi	
    done

    for i in $(cat $barcodefilepath$barcodefile)
    do
	if [[ $(find ./cnfr_result/ -maxdepth 1 -type f -name ${indexname}_barcode${i}_result.txt) = ./cnfr_result/${indexname}_barcode${i}_result.txt ]] ; then		    
	    combine	    
	else
	    echo "There is no ./cnfr_result/${indexname}_barcode${i}_result.txt."
	    continue
	fi
    done
    
else
    echo "
    please check the value of 'Is barcode coding serial?' must be 'Yes' or 'No'"
fi
bf=$(cat settings_centrifuge.csv | grep "barcode from" | cut -f 2 -d ",")
bt=$(cat settings_centrifuge.csv | grep "barcode to" | cut -f 2 -d ",")
# for i in $(seq -f "%02g" $bf $bt)
# do
#     echo $i
# #    find ../fast5/guppy/pass/ -maxdepth 1 -type d -name "barcode*"

# done
	 
conda deactivate
