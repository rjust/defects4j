fail_status_file=.test_failed.status
carton exec ./$1 # start the test
if [ $? -ne 0 ] ; then # if exit status is non zero  the fail status file
    out=`echo $1 | tr " ", "."`
    echo $out >> ${fail_status_file}
fi
