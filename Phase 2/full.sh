#!/bin/sh

#SET RUN PARAM HERE
get_size(){
	case "$1" in
		"L1")
			DATA_SIZE=48
			;;
		"L2")
			DATA_SIZE=170
			;;
		"L3")
	 		DATA_SIZE=950
			;;
		"RAM")
			DATA_SIZE=2000
			;;
		*)
			DATA_SIZE=48
			echo "L1 has been chosen by default"
			echo "Usage ./full.sh [L1|L2|L3|RAM] (default is L1)"
			;;
		esac
}

META=31 # number of meta repitions
WARM=20 # number of warmup iterations
REPT=200 # number of reps in a single run

get_size $1
plot_tsv() {
	bi=""
	for i in $(ls $1/*.tsv); do
		y=$(basename $i)
		y=$(echo "$y"| sed 's/\.[^.]*$//' | sed 's/\.[^.]*$//')
		gnuplot -e "set terminal png ; set xlabel 'metaiter'; set ylabel 'cycles/rept'; set output '$1/$y.png' ; plot '$i' with line title \"$y\""
		if [ -z "$bi" ] ; then
			bi="plot '$i' with line title \"$y\", "
		else
			bi="$bi '$i' with line title \"$y\","
		fi
	done
	gnuplot -e "set terminal png ; set xlabel 'metaiter'; set ylabel 'cycles/rept'; set output '$1/glob.png' ; $bi "
}

mkdir -p warmup
mkdir -p asm
mkdir -p metarep
mkdir -p cqa
mkdir -p likwid
make clean
TODO=$(tail -n +10 Makefile | grep : | cut -d : -f 1) # to be changed depending on the steps


echo '' > res.csv

echo - START TEST -

for i in $TODO ; do

	echo  - COMPIL $i -

	make $i

	echo - RUNNING $i -

	med=$(mktemp)

	echo '' > $med

	echo '' > "metarep/"$i".tsv"
	T=$(./$i ${WARM} ${REPT} ${DATA_SIZE})
	T=$(taskset -c 3 ./$i ${WARM} ${REPT} ${DATA_SIZE})
	echo $T >> $med
	echo "0	"$T >> "metarep/"$i".tsv"
	for j in $(seq 1 $META) ; do
		T=$(taskset -c 3 ./$i ${WARM} ${REPT} ${DATA_SIZE})
		echo $T >> $med
		echo $j"	"$T >> "metarep/"$i".tsv"

	done

	echo - RESULT WRITING FOR $i -

	z=$(sort -n $med | sed -ne "$(($META/2+1))p")

	echo $i" "$z >> res.csv
	#echo $z >> $i.tsv.median

	echo - SLEEP -

	sleep 3

done

echo  - PLOTING -
plot_tsv warmup

plot_tsv metarep

echo - CQA PASS -
for i in $(ls O*) ; do
	maqao cqa fct-loops=baseline uarch=SKYLAKE conf=all -vec-report ./$i > cqa/$i.cqa
done
echo - LIKWID PASS -
for i in $(ls O*) ; do
	likwid-perfctr -C 3 -g CYCLE_ACTIVITY ./$i 3 ${REPT} ${DATA_SIZE} > likwid/$i.txt
done

echo - DONE -
