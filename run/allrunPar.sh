nThreads=8 # default 8 threads
nameString="*gk*" # default string to search for

while getopts ":n:" arg
do	case "$arg" in
	n)  if (( "$OPTARG" + 0 )); then nThreads="$OPTARG"; else echo "needs to be a number"; exit 1; fi;;
	h | *)	echo "usage: ./allrunPar.sh [-n nthreads] [string passed to find in/ -name \$string]"; exit 1;;
	esac
done

shift $((OPTIND-1))

[ ! -z $1 ] && nameString="$1"

kill_descendant_processes()
{
    # ps -f --forest
    # iterates through a tree of descendant processes and kills them from the deepest up, avoiding losing orphaned processes
    local pid="$1"
    local and_self="${2:-false}"
    local signal="${3:-SIGTERM}"
    # debug outputs
    # echo "kill_descendant_processes: pid is $pid, andself is $and_self"
    # ps -f --forest
    #end of debug
    while children="$(pgrep -P "$pid")"; do # loop while child processes exist, in case more processes are spawned since last kill
        kill -0 `echo $children | cut -d " " -f1` 2>/dev/null || break # avoid race conditions by checking the first process is still running
        for child in $children; do # loop through and call this script on all descendant processes
            kill -0 $child 2>/dev/null && kill_descendant_processes "$child" true
        done
    done
    if kill -0 $pid 2>/dev/null && [[ "$and_self" == true ]]; then
        # echo "sending $signal to $pid"
        kill -$signal "$pid"
    fi
}

endfunc() {
    trap ' ' EXIT HUP INT QUIT PIPE TERM SIGALRM USR1 USR2
    echo "killing descendant processes"
    kill_descendant_processes $$ false
		wait
		./scripts/finish.sh
		# rm -r working/*
}
trap 'endfunc' EXIT

# add morpheus and unibetacode to path
. ../applications/loadApps

# clean working files
# rm -r working/*

# set up file lists
for i in `seq 1 "$nThreads"`; do
  >working/processor$i
done

# strange workaround to let find count
echo 0>working/i

queueFile() {
  inFile=`sed "s#^in/##" <<< "$1"`
  [ ! -e "in/$inFile" ] && echo "error: in/$inFile not found" && exit 1
  [ -e "out/$inFile.vert" ] && echo "out/$inFile.vert already exists, skipping" && return 0
  # if we're here, the input file exists and the output file does not
  i="`cat working/i`"

  threadNum=$(( i % nThreads + 1 ))
  echo $inFile >>working/processor$threadNum

  echo $(( ++i ))>working/i
}

export -f queueFile
export nThreads

find in -name "$nameString" -exec bash -c 'queueFile "$0"' {} \;

doFiles() {
  [ ! -e $1 ] && echo "error: $1 not found"
  while read -r inFile; do
    [ ! -e "in/$inFile" ] && echo "error: in/$inFile not found" && exit 1
    # make directory in working if it doesn't exist already
    mkdir -p "working/corpus/${inFile%/*}"
    cp "in/$inFile" "working/corpus/$inFile"
    ./scripts/allrun.sh "working/corpus/$inFile"
    mkdir -p "out/${inFile%/*}"
    mv "working/corpus/$inFile.vert" "out/$inFile.vert"
  done < $1
}

for i in working/processor*; do
  doFiles $i &
done

wait

echo "done"
