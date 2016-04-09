#PY  <- Needed to identify #
#--automatically built--

adm = Avidemux()
adm.videoCodec("xvid4", "params=CQ=5", "profile=244", "rdMode=3", "motionEstimation=3", "cqmMode=0", "arMode=1", "maxBFrame=2", "maxKeyFrameInterval=200", "nbThreads=99", "qMin=2", "qMax=25", "rdOnBFrame=True", "hqAcPred=True"
, "optimizeChrome=True", "trellis=True")
# adm.addVideoFilter("swscale", "width=720", "height=406", "algo=2", "sourceAR=2", "targetAR=2")
adm.audioClearTracks()
adm.setSourceTrackLanguage(0,"")
adm.audioAddTrack(0)
adm.audioCodec(0, "copy");
adm.audioSetDrc(0, 0)
adm.audioSetShift(0, 0,0)
adm.setContainer("AVI", "odmlType=1")
