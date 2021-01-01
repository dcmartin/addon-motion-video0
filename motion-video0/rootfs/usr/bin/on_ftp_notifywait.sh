#!/bin/tcsh

if ( $?MOTION_LOG_LEVEL ) then
  if ( ${MOTION_LOG_LEVEL} == "debug" ) setenv DEBUG
  if ( ${MOTION_LOG_LEVEL} == "trace" ) setenv DEBUG
endif

if ( $?MOTION_LOGTO == 0 ) then
  setenv MOTION_LOGTO /tmp/motion.log
endif

if ($?VERBOSE) echo "$0:t $$ -- START $*" `date` >>& ${MOTION_LOGTO}

if ($#argv == 2) then
  set file = "$argv[1]"
  set output = "$argv[2]"
  if (-s "$file") then
    switch ("$file:e")
      case "3gp":
	on_new_3gp.sh "$file" "$output"
	breaksw
      case "jpg":
	on_new_jpg.sh "$file" "$output"
	breaksw
      default:
	if ($?DEBUG) echo "$0:t $$ -- $file:e unimplemented" >>& ${MOTION_LOGTO}
	breaksw
    endsw
  else
    echo "$0:t $$ -- no such file: $file" >>& ${MOTION_LOGTO}
  endif
else
  echo "$0:t $$ -- invalid arguments $*" >>& ${MOTION_LOGTO}
endif

done:
  if ($?VERBOSE) echo "$0:t $$ -- FINISH" `date` >>& ${MOTION_LOGTO}
