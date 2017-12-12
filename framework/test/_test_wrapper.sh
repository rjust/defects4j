fail_status_file=".test_failed.status"
carton exec ./{$1} # start the test
wait $! # wait for it
if [ $? -ne 0 ] ; then # if exit status is non zero  the fail status file
    echo $1 >> ${fail_status_file}
fi
