
section == "MULTIPLEX" {
    # For multiplex select mplexid, frequency, sourceid from dtv_multiplex
    if (($1 + 0) == 0)
        next
    if ($3 != sourceid)
        next
    mplexid_by_freq[$2] = $1
    if (debug)
        print "MULTIPLEX mplexid_by_freq[" $2 "] = " $1
}

section == "SCAN" {
    if ($1 == "VC")
        section = "VC"
    if (debug)
        print "SCAN $1=" $1
}

section == "VC" {
    if ($1 == "CD" && $2 == "FREQUENCY") {
        section = "FREQUENCY"
        next
    }
    if (NF < 4)
        next
    if (($1 + 0) == 0)
        next
    split($2, chanpart,".")
    if ($1 in pchannel) {
        if (pchannel[$1]!=chanpart[1] || subchannel[$1]!=chanpart[2]) {
            print "ERROR Inconsistent data for Channel Number " $1 " in download"
            print "pchannel[" $1 "]=" pchannel[$1] "and " chanpart[1]
            print "subchannel[" $1 "]=" subchannel[$1] "and " chanpart[2]
            retcode = 2
        }
    }
    pchannel[$1]=chanpart[1]
    subchannel[$1]=chanpart[2]
    name[$1]=$4
    if (debug) {
        print "VC pchannel[" $1 "]=" chanpart[1]
        print "VC subchannel[" $1 "]=" chanpart[2]
        print "VC name[" $1 "]=" $4
    }
}

section == "FREQUENCY" {
    if ($1 == "M#") {
        section = "MODE"
        next
    }
    if (NF != 2)
        next
    if (($1 + 0) == 0)
        next
    freqval = substr($2,1,length($2)-2)
    if ((freqval + 0) == 0)
        next
    freq_by_channel[$1] = freqval
    if (debug)
        print "FREQUENCY freq_by_channel[" $1 "] = " freqval
}

section == "CHANNEL" {
    # for this section select chanid, channum, freqid, mplexid, serviceid, sourceid, callsign, name, xmltvid, recpriority, visible from channel
    if (($1 + 0) == 0)
        next
    if ($6 != sourceid)
        next
    chanid = $1
    channum = $2
    freqid = $3
    mplexid = $4
    serviceid = $5
    visible = $11

    if (!visible)
        next
    if (channum in pchannel) {
        newfreqid = pchannel[channum]
        if (newfreqid == "X") {
            print "ERROR Duplicate Channel Number " channum " in database"
            retcode = 2
            next
        }
        pchannel[channum] = "X"
        if (newfreqid in freq_by_channel)
            newfreq = freq_by_channel[newfreqid]
        else {
            print "ERROR Frequency " newfreqid " for channel " channum " is not in the downloaded frequency list"
            newfreq = "X"
            retcode = 2
            next
        }
        newmplexid = 0
        if (newfreq in mplexid_by_freq)
            newmplexid = mplexid_by_freq[newfreq]
        if (newmplexid == 0) {
            print "insert into dtv_multiplex (sourceid,modulation,sistandard,frequency,polarity, constellation,hierarchy,mod_sys,rolloff,default_authority, symbolrate) " > multiplexoutfile
            print "values (" sourceid ", 'qam_256', 'atsc','" newfreq "','v','qam_256','a','UNDEFINED','0.35','','0');" > multiplexoutfile
            # set here to avoid creating same entry more than once
            mplexid_by_freq[newfreq] = "X"
        }
        newserviceid = subchannel[channum]
        if (freqid != newfreqid \
            || mplexid != newmplexid \
            || serviceid != newserviceid) {
            print "update channel set freqid = " newfreqid ","> channeloutfile
            print "  mplexid = " newmplexid "," > channeloutfile
            print "  serviceid = " newserviceid  > channeloutfile
            print "  where channum = " channum  > channeloutfile
            print "  and sourceid = " sourceid ";"   > channeloutfile
            update_count++
        }
        if (debug) {
            print "CHANNEL " channum " freqid:" freqid "," newfreqid
            print "CHANNEL " channum " newfreq:" newfreq
            print "CHANNEL " channum " mplexid:" mplexid "," newmplexid
            print "CHANNEL " channum " serviceid:" serviceid "," newserviceid
        }
    }
    else {
        print "WARNING Channel Number " channum " not found in download."
        chanids_notfnd[chanid] = chanid
    }
}

END {
    exit retcode
}