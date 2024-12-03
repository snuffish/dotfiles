#!/bin/bash

function yottaDB_extractJournal() {
    if [ "$#" -ne 2 ]; then
        echo "You must specify 2 arguments"
        echo "Example: yottaDB_extractJournal extracted.mjf ~/.yottadb/r1.36_x86_64/g/yottadb.mjl"
        return 1
    fi

    which mupip >/dev/null 2>&1 || { echo "Application 'mupip' is not installed"; return 1; }

    outputFile=$1
    mjlFile=$2

    mupip journal -detail -extract=$outputFile -forward $mjlFile
}

gtmRoutinesAbsolutePath="${HOME}/Projects/gtm-routines/src/se/vgregion/su/micro/mikrolis/gtm/routines"
convertedPath=$(convertPathToWin32 $gtmRoutinesAbsolutePath)

alias {rtndir,gtmdir,routinesdir}="echo \"${convertedPath}\" | clip && cd ${gtmRoutinesAbsolutePath} && open ."

alias gtm_download_routines="scp vgdb1407:'/var/MikroLIS_Dev/.yottadb/r1.36_x86_64/r/*' ~/Projects/gtm-routines/src/se/vgregion/su/micro/mikrolis/gtm/routines"
