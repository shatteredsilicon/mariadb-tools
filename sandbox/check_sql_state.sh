#!/bin/bash
# author: Cole Busby
# purpose: utility to stop typing commands.

for i in 12345 12346 12347; do
	echo `mysql -u msandbox -pmsandbox -P $i -e "show slave status;"`
done
