#!/usr/bin/env bash

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "Killing..."
        exit 1
}

CUR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
case "$1" in
    1) NAME=$1 ;;
    *) NAME="test" ;;
esac

case "$2" in
    1) VIRTUOSO_ADDRESS=$2 ;;
    *) VIRTUOSO_ADDRESS="http://localhost:7130/sparql/" ;;
esac

case "$3" in
    1) SAGE_ADDRESS=$3 ;;
    *) SAGE_ADDRESS="http://localhost:7120/sparql/bsbm1k" ;;
esac

case "$4" in
    1) BUILD_JAR=$4 ;;
    *) BUILD_JAR="$CUR/../../build/libs/sage-sparql-void-fat-1.0.jar" ;;
esac

case "$5" in
    1) VIRTUOSO_DEFAULT_GRAPH=$5 ;;
    *) VIRTUOSO_DEFAULT_GRAPH="http://sage.univ-nantes.fr/bsbm1k" ;;
esac

case "$6" in
    1) QUERIES=$6 ;;
    *) QUERIES="$CUR/../../data/queries/queries-wo-construct.txt" ;;
esac

function run_virtuoso {
    V_PREFIX="$DIR/virtuoso-run-$i"
    rm -rf $V_PREFIX*
    RESULT_VIRTUOSO="$V_PREFIX.csv"
    touch "$RESULT_VIRTUOSO"
    # read queries
    input=$QUERIES
    let "q=1"
    while IFS= read -r query
    do
      echo "# Executing virtuoso query-$q and appending into: $RESULT_VIRTUOSO"
      FILE_RESULT="$V_PREFIX-query-$q-result.txt"
      bash "$CUR/execute-virtuoso-query.sh" "$query" $VIRTUOSO_ADDRESS $VIRTUOSO_DEFAULT_GRAPH $FILE_RESULT $RESULT_VIRTUOSO $BUILD_JAR
      let "q++"
    done < "$input"
}

function run_sage {
    S_PREFIX="$DIR/sage-run-$i"
    rm -rf $S_PREFIX*
    RESULT_SAGE="$S_PREFIX.csv"
    touch "$RESULT_SAGE"
    # read queries
    input=$QUERIES
    let "q=1"
    while IFS= read -r query
    do
      echo "# Executing sage query-$q and appending into: $RESULT_SAGE"
      FILE_RESULT="$S_PREFIX-query-$q-result.txt"
      bash "$CUR/execute-sage-query.sh" "$query" $SAGE_ADDRESS $FILE_RESULT $RESULT_SAGE $BUILD_JAR --optimized
      let "q++"
    done < "$input"
}

RUNS=1
DIR="$CUR/../../output/$NAME"

mkdir -p "$DIR"

command -v python3 >/dev/null 2>&1 || { echo >&2 "python3 required for processing files on csv files. Aborting."; exit 1; }
command -v java >/dev/null 2>&1 || { echo >&2 "java required for executing queries. Aborting."; exit 1; }

number_of_queries=$(wc -l $QUERIES | awk '{print $1}')
echo "Number of queries: " $number_of_queries

for i in $(seq 1 1 $RUNS)
do
    echo "===> Running exp in $DIR: $i... <==="
    # run the virtuoso experiment
    #run_virtuoso
    # run the sage experiment
    #run_sage
    # compute completeness
    rm -rf "$DIR/completeness-run-$i.csv"
    for j in $(seq 1 1 $number_of_queries)
    do
        echo " # Processing completeness test between virtuoso and sage on query $j for run $i..."
        # remove first line of both files
        SORT_V="$DIR/virtuoso-run-$i-query-$j-result.txt.sorted"
        SORT_S="$DIR/sage-run-$i-query-$j-result.txt.sorted"
        cat "$DIR/virtuoso-run-$i-query-$j-result.txt" | sed "s/\"//g" | awk 'NF' | sort > $SORT_V
        cat "$DIR/sage-run-$i-query-$j-result.txt" | awk 'NF' | sort > $SORT_S
        let "complete=0"
        let "incomplete=0"
        d=$(diff -b --changed-group-format='%<%>' --unchanged-group-format="" "$SORT_V" "$SORT_S" | wc -l | awk '{print $1}')
        rm $SORT_V $SORT_S
        if [ $d -eq 0 ]; then
            let "complete++"
            echo "$j, 1" >> "$DIR/completeness-run-$i.csv"
        else
            let "incomplete++"
            echo "$j, 0" >> "$DIR/completeness-run-$i.csv"
        fi

    done
done


python3 $CUR/average.py -f $DIR/sage-run*.csv -o $DIR/sage-average.csv
python3 $CUR/average.py -f $DIR/virtuoso-run*.csv -o $DIR/virtuoso-average.csv

