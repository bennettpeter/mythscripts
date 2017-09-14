#!/DO_NOT_EXECUTE
# This must be sourced into bash scripts instead of /etc/mythtv/mysql.txt
# It sets up environment variables for the fields from config.xml

if [[ "$MYTHCONFDIR" == "" ]] ; then
    MYTHCONFDIR="$HOME/.mythtv"
fi

paramfile=$MYTHCONFDIR/config.xml
if [[ ! -f $paramfile ]] ; then
    paramfile=/home/$SOFT_USER/.mythtv/config.xml
fi

# set -- `ls -lL "$paramfile"`
# filesize="$5"

# if [[ "$filesize" == 0 ]] ; then
#     echo "WARNING zero length config.xml"
#     cp -v $DATADIR/config.xml $paramfile
# fi

function parsexml {
    context=$1
    keyword=$2
    value=`xmllint $paramfile --xpath $context/$keyword` || true
    if [[ "$value" != "" ]] ; then
        value=`echo $value | sed -e "s~ *<$keyword>~~;s~</$keyword> *~~"`
    fi
#    eval $keyword=$value
}
if [[ -f $paramfile ]] ; then
    config=OLD
    if xmllint $paramfile --xpath //Configuration/Database/DatabaseName >/dev/null 2>&1 ; then
        config=NEW
    fi
    if [[ "$config" == OLD ]] ; then
        parsexml //Configuration/UPnP/MythFrontend/DefaultBackend DBHostName ; DBHostName=$value
        parsexml //Configuration/UPnP/MythFrontend/DefaultBackend DBUserName ; DBUserName=$value
        parsexml //Configuration/UPnP/MythFrontend/DefaultBackend DBPassword ; DBPassword=$value
        parsexml //Configuration/UPnP/MythFrontend/DefaultBackend DBName     ; DBName=$value
        parsexml //Configuration/UPnP/MythFrontend/DefaultBackend DBPort     ; DBPort=$value
        parsexml //Configuration/UPnP/MythFrontend/DefaultBackend LocalHostName ; LocalHostName=$value
    else
        parsexml //Configuration/Database Host         ; DBHostName=$value
        parsexml //Configuration/Database UserName     ; DBUserName=$value
        parsexml //Configuration/Database Password     ; DBPassword=$value
        parsexml //Configuration/Database DatabaseName ; DBName=$value
        parsexml //Configuration/Database Port         ; DBPort=$value
        parsexml //Configuration LocalHostName         ; LocalHostName=$value
    fi
fi
if [[ "$LocalHostName" == "" || "$LocalHostName" == "my-unique-identifier-goes-here" ]]; then
    LocalHostName=`cat /etc/hostname`
fi
if [[ "$DBHostName" == "" ]] ; then
    echo "ERROR parsing config.xml"
fi

mysqlcmd="mysql -N --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

