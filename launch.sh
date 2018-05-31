MACHINE=$1
if echo $MACHINE | grep -q '@'; then
    USER=$(echo $MACHINE | cut -d@ -f1)
    MACHINE=$(echo $MACHINE | cut -d@ -f2)
else
    USER=ubuntu
fi

shift
if lxc ls | grep $MACHINE | grep -q STOPPED; then
    lxc start $MACHINE
fi

lxc exec $MACHINE -- sudo --login --user $USER "$@"
