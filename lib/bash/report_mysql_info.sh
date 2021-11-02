# This program is copyright 2011 Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
# ###########################################################################
# report_mysql_info package
# ###########################################################################

# Package: report_mysql_info
# Report various aspects of MySQL
set -u
POSIXLY_CORRECT=1

secs_to_time () {
   awk -v sec="$1" 'BEGIN {
      printf( "%d+%02d:%02d:%02d", sec / 86400, (sec % 86400) / 3600, (sec % 3600) / 60, sec % 60);
   }'
}

feat_on() {
   local file="$1"
   local varname="$2"
   [ -e "$file" ] || return

   if [ "$( grep "$varname" "${file}" )" ]; then
      local var="$(awk "\$1 ~ /^$2$/ { print \$2 }" $file)"
      if [ "${var}" = "ON" ]; then
         echo "Enabled"
      elif [ "${var}" = "OFF" -o "${var}" = "0" -o -z "${var}" ]; then
         echo "Disabled"
      elif [ "${3:-""}" = "ne" ]; then
         if [ "${var}" != "$4" ]; then
            echo "Enabled"
         else
            echo "Disabled"
         fi
      elif [ "${3:-""}" = "gt" ]; then
         if [ "${var}" -gt "$4" ]; then
            echo "Enabled"
         else
            echo "Disabled"
         fi
      elif [ "${var}" ]; then
         echo "Enabled"
      else
         echo "Disabled"
      fi
   else
      echo "Not Installed or Available"
   fi
}

feat_on_renamed () {
   local file="$1"
   shift;

   for varname in "$@"; do
      local feat_on="$( feat_on "$file" $varname )"
      if [ "${feat_on:-"Not Supported"}" != "Not Supported" ]; then
         echo $feat_on
         return
      fi
   done

   echo "Not Supported"
}

get_table_cache () {
   local file="$1"

   [ -e "$file" ] || return

   local table_cache=""
   if [ "$( get_var table_open_cache "${file}" )" ]; then
      table_cache="$(get_var table_open_cache "${file}")"
   else
      table_cache="$(get_var table_cache "${file}")"
   fi
   echo ${table_cache:-0}
}

get_plugin_status () {
   local file="$1"
   local plugin="$2"

   local status="$(grep -w "$plugin" "$file" | awk '{ print $2 }')"

   echo ${status:-"Not found"}
}

collect_keyring_plugins() {
    $CMD_MYSQL $EXT_ARGV --table -ss -e 'SELECT PLUGIN_NAME, PLUGIN_STATUS FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_NAME LIKE "keyring%";'
}

collect_encrypted_tables() {
    $CMD_MYSQL $EXT_ARGV --table -ss -e "SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_OPTIONS FROM INFORMATION_SCHEMA.TABLES WHERE CREATE_OPTIONS LIKE '%ENCRYPTION=\"Y\"%';"
}

collect_encrypted_tablespaces() {
    $CMD_MYSQL $EXT_ARGV --table -ss -e "SELECT SPACE, NAME, SPACE_TYPE from INFORMATION_SCHEMA.INNODB_SYS_TABLESPACES where FLAG&8192 = 8192;"
}



_NO_FALSE_NEGATIVES=""
parse_mysqld_instances () {
   local file="$1"
   local variables_file="$2"

   local socket=""
   local port=""
   local datadir=""
   local defaults_file=""

   [ -e "$file" ] || return

   echo "  Port  Data Directory             Nice OOM Socket"
   echo "  ===== ========================== ==== === ======"

   grep '/mysqld ' "$file" | while read line; do
      local pid=$(echo "$line" | awk '{print $1;}')
      for word in ${line}; do
         if echo "${word}" | grep -- "--socket=" > /dev/null; then
            socket="$(echo "${word}" | cut -d= -f2)"
         fi
         if echo "${word}" | grep -- "--port=" > /dev/null; then
            port="$(echo "${word}" | cut -d= -f2)"
         fi
         if echo "${word}" | grep -- "--datadir=" > /dev/null; then
            datadir="$(echo "${word}" | cut -d= -f2)"
         fi
         if echo "${word}" | grep -- "--defaults-file=" > /dev/null; then
            defaults_file="$(echo "${word}" | cut -d= -f2)"
         fi
      done
      
      if [ -n "${defaults_file:-""}" -a -r "${defaults_file:-""}" ]; then
         socket="${socket:-"$(grep "^socket\>" "$defaults_file" | tail -n1 | cut -d= -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')"}"
         port="${port:-"$(grep "^port\>" "$defaults_file" | tail -n1 | cut -d= -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')"}"
         datadir="${datadir:-"$(grep "^datadir\>" "$defaults_file" | tail -n1 | cut -d= -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')"}"
      fi

      local nice="$(get_var "internal::nice_of_$pid" "$variables_file")"
      local oom="$(get_var "internal::oom_of_$pid" "$variables_file")"
      if [ -n "${_NO_FALSE_NEGATIVES}" ]; then
         nice="?"
         oom="?"
      fi
      printf "  %5s %-26s %-4s %-3s %s\n" "${port}" "${datadir}" "${nice:-"?"}" "${oom:-"?"}" "${socket}"
      
      defaults_file=""
      socket=""
      port=""
      datadir=""
   done
}

get_mysql_timezone () {
   local file="$1"

   [ -e "$file" ] || return

   local tz="$(get_var time_zone "${file}")"
   if [ "${tz}" = "SYSTEM" ]; then
      tz="$(get_var system_time_zone "${file}")"
   fi
   echo "${tz}"
}

get_mysql_version () {
   local file="$1"

   name_val Version "$(get_var version "${file}") $(get_var version_comment "${file}")"
   name_val "Built On" "$(get_var version_compile_os "${file}") $(get_var version_compile_machine "${file}")"
}

get_mysql_uptime () {
   local uptime="$1"
   local restart="$2"
   uptime="$(secs_to_time ${uptime})"
   echo "${restart} (up ${uptime})"
}

summarize_binlogs () {
   local file="$1"

   [ -e "$file" ] || return

   local size="$(awk '{t += $2} END{printf "%0.f\n", t}' "$file")"
   name_val "Binlogs" $(wc -l "$file")
   name_val "Zero-Sized" $(grep -c '\<0$' "$file")
   name_val "Total Size" $(shorten ${size} 1)
}

format_users () {
   local file="$1"
   [ -e "$file" ] || return
   awk '{printf "%d users, %d anon, %d w/o pw, %d old pw\n", $1, $2, $3, $4}' "${file}"
}

format_binlog_filters () {
   local file="$1"
   [ -e "$file" ] || return
   name_val "binlog_do_db" "$(cut -f3 "$file")"
   name_val "binlog_ignore_db" "$(cut -f4 "$file")"
}

format_status_variables () {
   local file="$1"
   [ -e "$file" ] || return

   utime1="$(awk '/Uptime /{print $2}' "$file")";
   utime2="$(awk '/Uptime /{print $3}' "$file")";
   awk "
   BEGIN {
      utime1 = ${utime1};
      utime2 = ${utime2};
      udays  = utime1 / 86400;
      udiff  = utime2 - utime1;
      printf(\"%-35s %11s %11s %11s\\n\", \"Variable\", \"Per day\", \"Per second\", udiff \" secs\");
   }
   \$2 ~ /^[0-9]*\$/ {
      if ( \$2 > 0 && \$2 < 18446744073709551615 ) {
         if ( udays > 0 ) {
            fuzzy_var=\$2 / udays;
            ${fuzzy_formula};
            perday=fuzzy_var;
         }
         if ( utime1 > 0 ) {
            fuzzy_var=\$2 / utime1;
            ${fuzzy_formula};
            persec=fuzzy_var;
         }
         if ( udiff > 0 ) {
            fuzzy_var=(\$3 - \$2) / udiff;
            ${fuzzy_formula};
            nowsec=fuzzy_var;
         }
         perday = int(perday);
         persec = int(persec);
         nowsec = int(nowsec);
         if ( perday + persec + nowsec > 0 ) {
            perday_format=\"%11.f\";
            persec_format=\"%11.f\";
            nowsec_format=\"%11.f\";
            if ( perday == 0 ) { perday = \"\"; perday_format=\"%11s\"; }
            if ( persec == 0 ) { persec = \"\"; persec_format=\"%11s\"; }
            if ( nowsec == 0 ) { nowsec = \"\"; nowsec_format=\"%11s\"; }
            format=\"%-35s \" perday_format \" \" persec_format \" \" nowsec_format \"\\n\";
            printf(format, \$1, perday, persec, nowsec);
         }
      }
   }" "$file"
}

summarize_processlist () {
   local file="$1"

   [ -e "$file" ] || return

   for param in Command User Host db State; do
      echo
      printf '  %-30s %8s %7s %9s %9s\n' \
         "${param}" "COUNT(*)" Working "SUM(Time)" "MAX(Time)"
      echo "  ------------------------------" \
         "-------- ------- --------- ---------"
      cut -c1-80 "$file" \
         | awk "
         \$1 == \"${param}:\" {
            p = substr(\$0, index(\$0, \":\") + 2);
            if ( index(p, \":\") > 0 ) {
               p = substr(p, 1, index(p, \":\") - 1);
            }
            if ( length(p) > 30 ) {
               p = substr(p, 1, 30);
            }
         }
         \$1 == \"Time:\" {
            t = \$2;
            if ( t == \"NULL\" ) { 
                t = 0;
            }
         }
         \$1 == \"Command:\" {
            c = \$2;
         }
         \$1 == \"Info:\" {
            count[p]++;
            if ( c == \"Sleep\" ) {
               sleep[p]++;
            }
            if ( \"${param}\" == \"Command\" || c != \"Sleep\" ) {
               time[p] += t;
               if ( t > mtime[p] ) { mtime[p] = t; }
            }
         }
         END {
            for ( p in count ) {
               fuzzy_var=count[p]-sleep[p]; ${fuzzy_formula} fuzzy_work=fuzzy_var;
               fuzzy_var=count[p];          ${fuzzy_formula} fuzzy_count=fuzzy_var;
               fuzzy_var=time[p];           ${fuzzy_formula} fuzzy_time=fuzzy_var;
               fuzzy_var=mtime[p];          ${fuzzy_formula} fuzzy_mtime=fuzzy_var;
               printf \"  %-30s %8d %7d %9d %9d\n\", p, fuzzy_count, fuzzy_work, fuzzy_time, fuzzy_mtime;
            }
         }
      " | sort
   done
   echo
}

pretty_print_cnf_file () {
   local file="$1"

   [ -e "$file" ] || return

   perl -n -l -e '
      my $line = $_;
      if ( $line =~ /^\s*[a-zA-Z[]/ ) { 
         if ( $line=~/\s*(.*?)\s*=\s*(.*)\s*$/ ) { 
            printf("%-35s = %s\n", $1, $2)  
         } 
         elsif ( $line =~ /\s*\[/ ) { 
            print "\n$line" 
         } else {
            print $line
         } 
      }' "$file"

}


find_checkpoint_age() {
   local file="$1"
   awk '
   /Log sequence number/{
      if ( $5 ) {
         lsn = $5 + ($4 * 4294967296);
      }
      else {
         lsn = $4;
      }
   }
   /Last checkpoint at/{
      if ( $5 ) {
         print lsn - ($5 + ($4 * 4294967296));
      }
      else {
         print lsn - $4;
      }
   }
   ' "$file"
}

find_pending_io_reads() {
   local file="$1"

   [ -e "$file" ] || return

   awk '
   /Pending normal aio reads/ {
      normal_aio_reads  = substr($5, 1, index($5, ","));
   }
   /ibuf aio reads/ {
      ibuf_aio_reads = substr($4, 1, index($4, ","));
   }
   /pending preads/ {
      preads = $1;
   }
   /Pending reads/ {
      reads = $3;
   }
   END {
      printf "%d buf pool reads, %d normal AIO", reads, normal_aio_reads;
      printf ", %d ibuf AIO, %d preads", ibuf_aio_reads, preads;
   }
   ' "${file}"
}

find_pending_io_writes() {
   local file="$1"

   [ -e "$file" ] || return

   awk '
   /aio writes/ {
      aio_writes = substr($NF, 1, index($NF, ","));
   }
   /ibuf aio reads/ {
      log_ios = substr($7, 1, index($7, ","));
      sync_ios = substr($10, 1, index($10, ","));
   }
   /pending log writes/ {
      log_writes = $1;
      chkp_writes = $5;
   }
   /pending pwrites/ {
      pwrites = $4;
   }
   /Pending writes:/ {
      lru = substr($4, 1, index($4, ","));
      flush_list = substr($7, 1, index($7, ","));
      single_page = $NF;
   }
   END {
      printf "%d buf pool (%d LRU, %d flush list, %d page); %d AIO, %d sync, %d log IO (%d log, %d chkp); %d pwrites", lru + flush_list + single_page, lru, flush_list, single_page, aio_writes, sync_ios, log_ios, log_writes, chkp_writes, pwrites;
   }
   ' "${file}"
}

find_pending_io_flushes() {
   local file="$1"

   [ -e "$file" ] || return

   awk '
   /Pending flushes/ {
      log_flushes = substr($5, 1, index($5, ";"));
      buf_pool = $NF;
   }
   END {
      printf "%d buf pool, %d log", buf_pool, log_flushes;
   }
   ' "${file}"
}

summarize_undo_log_entries() {
   local file="$1"

   [ -e "$file" ] || return

   grep 'undo log entries' "${file}" \
      | sed -e 's/^.*undo log entries \([0-9]*\)/\1/' \
      | awk '
      {
         count++;
         sum += $1;
         if ( $1 > max ) {
            max = $1;
         }
      }
      END {
         printf "%d transactions, %d total undo, %d max undo\n", count, sum, max;
      }'
}

find_max_trx_time() {
   local file="$1"

   [ -e "$file" ] || return

   awk '
   BEGIN {
      max = 0;
   }
   /^---TRANSACTION.* sec,/ {
      for ( i = 0; i < 7; ++i ) {
         if ( $i == "sec," ) {
            j = i-1;
            if ( max < $j ) {
               max = $j;
            }
         }
      }
   }
   END {
      print max;
   }' "${file}"
}

find_transation_states () {
   local file="$1"
   local tmpfile="$PT_TMPDIR/find_transation_states.tmp"

   [ -e "$file" ] || return

   awk -F, '/^---TRANSACTION/{print $2}' "${file}"   \
                        | sed -e 's/ [0-9]* sec.*//' \
                        | sort                       \
                        | uniq -c > "${tmpfile}"
   group_concat "${tmpfile}"
}

format_innodb_status () {
   local file=$1

   [ -e "$file" ] || return

   name_val "Checkpoint Age"      "$(shorten $(find_checkpoint_age "${file}") 0)"
   name_val "InnoDB Queue"        "$(awk '/queries inside/{print}' "${file}")"
   name_val "Oldest Transaction"  "$(find_max_trx_time "${file}") Seconds";
   name_val "History List Len"    "$(awk '/History list length/{print $4}' "${file}")"
   name_val "Read Views"          "$(awk '/read views open inside/{print $1}' "${file}")"
   name_val "Undo Log Entries"    "$(summarize_undo_log_entries "${file}")"
   name_val "Pending I/O Reads"   "$(find_pending_io_reads "${file}")"
   name_val "Pending I/O Writes"  "$(find_pending_io_writes "${file}")"
   name_val "Pending I/O Flushes" "$(find_pending_io_flushes "${file}")"
   name_val "Transaction States"  "$(find_transation_states "${file}" )"
   if grep 'TABLE LOCK table' "${file}" >/dev/null ; then
      echo "Tables Locked"
      awk '/^TABLE LOCK table/{print $4}' "${file}" \
         | sort | uniq -c | sort -rn
   fi
   if grep 'has waited at' "${file}" > /dev/null ; then
      echo "Semaphore Waits"
      grep 'has waited at' "${file}" | cut -d' ' -f6-8 \
         | sort | uniq -c | sort -rn
   fi
   if grep 'reserved it in mode' "${file}" > /dev/null; then
      echo "Semaphore Holders"
      awk '/has reserved it in mode/{
         print substr($0, 1 + index($0, "("), index($0, ")") - index($0, "(") - 1);
      }' "${file}" | sort | uniq -c | sort -rn
   fi
   if grep -e 'Mutex at' -e 'lock on' "${file}" >/dev/null 2>&1; then
      echo "Mutexes/Locks Waited For"
      grep -e 'Mutex at' -e 'lock on' "${file}" | sed -e 's/^[XS]-//' -e 's/,.*$//' \
         | sort | uniq -c | sort -rn
   fi
}

format_cs_status() {
   local file=$1

   [ -e "$file" ] || return
   egrep '^[ \t]*Name:|[ \t]*Status:' $file|sed 's/^[ \t]*//g'|while read line; do echo $line; echo $line | grep '^Status:'>/dev/null && echo ; done
}

format_keyring_plugins() {
    local keyring_plugins="$1"
    local encrypted_tables="$2"

    if [ -z "$keyring_plugins" ]; then 
        echo "No keyring plugins found"
        if [ ! -z "$encrypted_tables" ]; then
            echo "Warning! There are encrypted tables but keyring plugins are not loaded"
        fi
     else
        echo "Keyring plugins:"
        echo "'$keyring_plugins'"
    fi
}

format_encrypted_tables() {
   local encrypted_tables="$1"
   if [ ! -z "$encrypted_tables" ]; then
       echo "Encrypted tables:"
       echo "$encrypted_tables"
   fi
}

format_encrypted_tablespaces() {
   local encrypted_tablespaces="$1"
   if [ ! -z "$encrypted_tablespaces" ]; then
       echo "Encrypted tablespaces:"
       echo "$encrypted_tablespaces"
   fi
}

format_mysql_roles() {
   local file=$1
   [ -e "$file" ] || return
   cat $file
}

format_overall_db_stats () {
   local file="$1"
   local tmpfile="$PT_TMPDIR/format_overall_db_stats.tmp"

   [ -e "$file" ] || return

   echo
   awk '
      BEGIN {
         db      = "{chosen}";
         num_dbs = 0;
      }
      /^USE `.*`;$/ {
         db = substr($2, 2, length($2) - 3);
         if ( db_seen[db]++ == 0 ) {
            dbs[num_dbs] = db;
            num_dbs++;
         }
      }
      /^CREATE TABLE/ {
         if (num_dbs == 0) {
            num_dbs     = 1;
            db_seen[db] = 1;
            dbs[0]      = db;
         }
         counts[db ",tables"]++;
      }
      /CREATE ALGORITHM=/ {
         counts[db ",views"]++;
      }
      /03 CREATE.*03 PROCEDURE/ {
         counts[db ",sps"]++;
      }
      /03 CREATE.*03 FUNCTION/ {
         counts[db ",func"]++;
      }
      /03 CREATE.*03 TRIGGER/ {
         counts[db ",trg"]++;
      }
      /FOREIGN KEY/ {
         counts[db ",fk"]++;
      }
      /PARTITION BY/ {
         counts[db ",partn"]++;
      }
      END {
         mdb = length("Database");
         for ( i = 0; i < num_dbs; i++ ) {
            if ( length(dbs[i]) > mdb ) {
               mdb = length(dbs[i]);
            }
         }
         fmt = "  %-" mdb "s %6s %5s %3s %5s %5s %5s %5s\n";
         printf fmt, "Database", "Tables", "Views", "SPs", "Trigs", "Funcs", "FKs", "Partn";
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            printf fmt, db, counts[db ",tables"], counts[db ",views"], counts[db ",sps"], counts[db ",trg"], counts[db ",func"], counts[db ",fk"], counts[db ",partn"];
         }
      }
   ' "$file" > "$tmpfile"
   head -n2 "$tmpfile"
   tail -n +3 "$tmpfile" | sort

   echo
   awk '
      BEGIN {
         db          = "{chosen}";
         num_dbs     = 0;
         num_engines = 0;
      }
      /^USE `.*`;$/ {
         db = substr($2, 2, length($2) - 3);
         if ( db_seen[db]++ == 0 ) {
            dbs[num_dbs] = db;
            num_dbs++;
         }
      }
      /^\) ENGINE=/ {
         if (num_dbs == 0) {
            num_dbs     = 1;
            db_seen[db] = 1;
            dbs[0]      = db;
         }
         engine=substr($2, index($2, "=") + 1);
         if ( engine_seen[tolower(engine)]++ == 0 ) {
            engines[num_engines] = engine;
            num_engines++;
         }
         counts[db "," engine]++;
      }
      END {
         mdb = length("Database");
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            if ( length(db) > mdb ) {
               mdb = length(db);
            }
         }
         fmt = "  %-" mdb "s"
         printf fmt, "Database";
         for ( i=0;i<num_engines;i++ ) {
            engine = engines[i];
            fmts[engine] = " %" length(engine) "s";
            printf fmts[engine], engine;
         }
         print "";
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            printf fmt, db;
            for ( j=0;j<num_engines;j++ ) {
               engine = engines[j];
               printf fmts[engine], counts[db "," engine];
            }
            print "";
         }
      }
   ' "$file" > "$tmpfile"
   head -n1 "$tmpfile"
   tail -n +2 "$tmpfile" | sort

   echo
   awk '
      BEGIN {
         db        = "{chosen}";
         num_dbs   = 0;
         num_idxes = 0;
      }
      /^USE `.*`;$/ {
         db = substr($2, 2, length($2) - 3);
         if ( db_seen[db]++ == 0 ) {
            dbs[num_dbs] = db;
            num_dbs++;
         }
      }
      /KEY/ {
         if (num_dbs == 0) {
            num_dbs     = 1;
            db_seen[db] = 1;
            dbs[0]      = db;
         }
         idx="BTREE";
         if ( $0 ~ /SPATIAL/ ) {
            idx="SPATIAL";
         }
         if ( $0 ~ /FULLTEXT/ ) {
            idx="FULLTEXT";
         }
         if ( $0 ~ /USING RTREE/ ) {
            idx="RTREE";
         }
         if ( $0 ~ /USING HASH/ ) {
            idx="HASH";
         }
         if ( idx_seen[idx]++ == 0 ) {
            idxes[num_idxes] = idx;
            num_idxes++;
         }
         counts[db "," idx]++;
      }
      END {
         mdb = length("Database");
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            if ( length(db) > mdb ) {
               mdb = length(db);
            }
         }
         fmt = "  %-" mdb "s"
         printf fmt, "Database";
         for ( i=0;i<num_idxes;i++ ) {
            idx = idxes[i];
            fmts[idx] = " %" length(idx) "s";
            printf fmts[idx], idx;
         }
         print "";
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            printf fmt, db;
            for ( j=0;j<num_idxes;j++ ) {
               idx = idxes[j];
               printf fmts[idx], counts[db "," idx];
            }
            print "";
         }
      }
   ' "$file" > "$tmpfile"
   head -n1 "$tmpfile"
   tail -n +2 "$tmpfile" | sort

   echo
   awk '
      BEGIN {
         db          = "{chosen}";
         num_dbs     = 0;
         num_types = 0;
      }
      /^USE `.*`;$/ {
         db = substr($2, 2, length($2) - 3);
         if ( db_seen[db]++ == 0 ) {
            dbs[num_dbs] = db;
            num_dbs++;
         }
      }
      /^  `/ {
         if (num_dbs == 0) {
            num_dbs     = 1;
            db_seen[db] = 1;
            dbs[0]      = db;
         }
         str = $0;
         str = substr(str, index(str, "`") + 1);
         str = substr(str, index(str, "`") + 2);
         if ( index(str, " ") > 0 ) {
            str = substr(str, 1, index(str, " ") - 1);
         }
         if ( index(str, ",") > 0 ) {
            str = substr(str, 1, index(str, ",") - 1);
         }
         if ( index(str, "(") > 0 ) {
            str = substr(str, 1, index(str, "(") - 1);
         }
         type = str;
         if ( type_seen[type]++ == 0 ) {
            types[num_types] = type;
            num_types++;
         }
         counts[db "," type]++;
      }
      END {
         mdb = length("Database");
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            if ( length(db) > mdb ) {
               mdb = length(db);
            }
         }
         fmt = "  %-" mdb "s"
         mtlen = 0; # max type length
         for ( i=0;i<num_types;i++ ) {
            type = types[i];
            if ( length(type) > mtlen ) {
               mtlen = length(type);
            }
         }
         for ( i=1;i<=mtlen;i++ ) {
            printf "  %-" mdb "s", "";
            for ( j=0;j<num_types;j++ ) {
               type = types[j];
               if ( i > length(type) ) {
                  ch = " ";
               }
               else {
                  ch = substr(type, i, 1);
               }
               printf(" %3s", ch);
            }
            print "";
         }
         printf "  %-" mdb "s", "Database";
         for ( i=0;i<num_types;i++ ) {
            printf " %3s", "===";
         }
         print "";
         for ( i=0;i<num_dbs;i++ ) {
            db = dbs[i];
            printf fmt, db;
            for ( j=0;j<num_types;j++ ) {
               type = types[j];
               printf " %3s", counts[db "," type];
            }
            print "";
         }
      }
   ' "$file" > "$tmpfile"
   local hdr=$(grep -n Database "$tmpfile" | cut -d: -f1);
   head -n${hdr} "$tmpfile"
   tail -n +$((${hdr} + 1)) "$tmpfile" | sort
   echo
}

section_mariadb_server_features () {
   local file="$1"

   [ -e "$file" ] || return

   name_val "Table & Index Stats"   \
            "$(feat_on_renamed "$file" userstat_running userstat)"
   name_val "Multiple I/O Threads"  \
            "$(feat_on "$file" innodb_read_io_threads gt 1)"
   
   name_val "Corruption Resilient"  \
            "$(feat_on_renamed "$file" innodb_pass_corrupt_table innodb_corrupt_table_action)"

   name_val "Durable Replication"   \
            "$(feat_on_renamed "$file" innodb_overwrite_relay_log_info innodb_recovery_update_relay_log)"

   name_val "Import InnoDB Tables"  \
            "$(feat_on_renamed "$file" innodb_expand_import innodb_import_table_from_xtrabackup)"

   name_val "Fast Server Restarts"  \
            "$(feat_on_renamed "$file" innodb_auto_lru_dump innodb_buffer_pool_restore_at_startup)"

   name_val "Enhanced Logging"      \
            "$(feat_on "$file" log_slow_verbosity ne microtime)"
   name_val "Replica Perf Logging"  \
            "$(feat_on "$file" log_slow_slave_statements)"

   name_val "Response Time Hist."   \
            "$(feat_on_renamed "$file" enable_query_response_time_stats query_response_time_stats)"

   local smooth_flushing="$(feat_on_renamed "$file" innodb_adaptive_checkpoint innodb_adaptive_flushing_method)"
   if  [ "${smooth_flushing:-""}" != "Not Supported" ]; then
      if [ -n "$(get_var innodb_adaptive_checkpoint "$file")" ]; then
         smooth_flushing="$(feat_on "$file" "innodb_adaptive_checkpoint" ne none)"
      else
         smooth_flushing="$(feat_on "$file" "innodb_adaptive_flushing_method" ne native)"
      fi
   fi
   name_val "Smooth Flushing" "$smooth_flushing"
   
   name_val "HandlerSocket NoSQL"   \
            "$(feat_on "$file" handlersocket_port)"

   name_val "Fast Hash UDFs"   \
            "$(get_var "pt-summary-internal-FNV_64" "$file")"
}

section_myisam () {
   local variables_file="$1"
   local status_file="$2"

   [ -e "$variables_file" -a -e "$status_file" ] || return

   local buf_size="$(get_var key_buffer_size "$variables_file")"
   local blk_size="$(get_var key_cache_block_size "$variables_file")"
   local blk_unus="$(get_var Key_blocks_unused "$status_file")"
   local blk_unfl="$(get_var Key_blocks_not_flushed "$variables_file")"
   local unus=$((${blk_unus:-0} * ${blk_size:-0}))
   local unfl=$((${blk_unfl:-0} * ${blk_size:-0}))
   local used=$((${buf_size:-0} - ${unus}))

   name_val "Key Cache" "$(shorten ${buf_size} 1)"
   name_val "Pct Used" "$(fuzzy_pct ${used} ${buf_size})"
   name_val "Unflushed" "$(fuzzy_pct ${unfl} ${buf_size})"
}

section_aria () {
   local variables_file="$1"
   local status_file="$2"

   [ -e "$variables_file" -a -e "$status_file" ] || return

   local buf_size="$(get_var aria_pagecache_buffer_size "$variables_file")"
   local blk_size="$(get_var aria_block_size "$variables_file")"
   local blk_unus="$(get_var Aria_pagecache_blocks_unused "$status_file")"
   local blk_unfl="$(get_var Aria_pagecache_blocks_not_flushed "$variables_file")"
   local unus=$((${blk_unus:-0} * ${blk_size:-0}))
   local unfl=$((${blk_unfl:-0} * ${blk_size:-0}))
   local used=$((${buf_size:-0} - ${unus}))

   name_val "Page Cache Buffer" "$(shorten ${buf_size} 1)"
   name_val "Pct Used" "$(fuzzy_pct ${used} ${buf_size})"
   name_val "Unflushed" "$(fuzzy_pct ${unfl} ${buf_size})"
}

section_innodb () {
   local variables_file="$1"
   local status_file="$2"

   [ -e "$variables_file" -a -e "$status_file" ] || return

   local version=$(get_var innodb_version "$variables_file")
   name_val Version ${version:-default}

   local bp_size="$(get_var innodb_buffer_pool_size "$variables_file")"
   name_val "Buffer Pool Size" "$(shorten "${bp_size:-0}" 1)"

   local bp_pags="$(get_var Innodb_buffer_pool_pages_total "$status_file")"
   local bp_free="$(get_var Innodb_buffer_pool_pages_free "$status_file")"
   local bp_dirt="$(get_var Innodb_buffer_pool_pages_dirty "$status_file")"
   local bp_fill=$((${bp_pags} - ${bp_free}))
   name_val "Buffer Pool Fill"   "$(fuzzy_pct ${bp_fill} ${bp_pags})"
   name_val "Buffer Pool Dirty"  "$(fuzzy_pct ${bp_dirt} ${bp_pags})"

   name_val "File Per Table"      $(get_var innodb_file_per_table "$variables_file")
   name_val "Page Size"           $(shorten $(get_var Innodb_page_size "$status_file") 0)

   local log_size="$(get_var innodb_log_file_size "$variables_file")"
   major_version=`echo $version | cut -d '.' -f 1`
   minor_version=`echo $version | cut -d '.' -f 2`
   dep_major_version="10"
   dep_minor_version="6" # innodb_log_files_in_group removed in 10.6 (https://mariadb.com/kb/en/innodb-system-variables/#innodb_log_files_in_group)
   if [[ "$major_version" -ge "$dep_major_version" ]] && [[ "$minor_version" -ge "$dep_minor_version" ]]; then 
      log_file="1"
   else
      local log_file="$(get_var innodb_log_files_in_group "$variables_file")"
   fi
   local log_total=$(awk "BEGIN {printf \"%.2f\n\", ${log_size}*${log_file}}" )
   name_val "Log File Size"       \
            "${log_file} * $(shorten ${log_size} 1) = $(shorten ${log_total} 1)"
   name_val "Log Buffer Size"     \
            "$(shorten $(get_var innodb_log_buffer_size "$variables_file") 0)"
   name_val "Flush Method"        \
            "$(get_var innodb_flush_method "$variables_file")"
   name_val "Flush Log At Commit" \
            "$(get_var innodb_flush_log_at_trx_commit "$variables_file")"
   name_val "XA Support"          \
            "$(get_var innodb_support_xa "$variables_file")"
   name_val "Checksums"           \
            "$(get_var innodb_checksums "$variables_file")"
   name_val "Doublewrite"         \
            "$(get_var innodb_doublewrite "$variables_file")"
   name_val "R/W I/O Threads"     \
            "$(get_var innodb_read_io_threads "$variables_file") $(get_var innodb_write_io_threads "$variables_file")"
   name_val "I/O Capacity"        \
            "$(get_var innodb_io_capacity "$variables_file")"
   name_val "Thread Concurrency"  \
            "$(get_var innodb_thread_concurrency "$variables_file")"
   name_val "Concurrency Tickets" \
            "$(get_var innodb_concurrency_tickets "$variables_file")"
   name_val "Commit Concurrency"  \
            "$(get_var innodb_commit_concurrency "$variables_file")"
   name_val "Txn Isolation Level" \
            "$(get_var tx_isolation "$variables_file")"
   name_val "Adaptive Flushing"   \
            "$(get_var innodb_adaptive_flushing "$variables_file")"
   name_val "Adaptive Checkpoint" \
            "$(get_var innodb_adaptive_checkpoint "$variables_file")"
}

section_rocksdb () {
    local variables_file="$1"
    local status_file="$2"

    local NAME_VAL_LEN=32

    [ -e "$variables_file" -a -e "$status_file" ] || return

    name_val "Block Cache Size" "$(shorten $(get_var rocksdb_block_cache_size "$variables_file") 0)"
    name_val "Block Size" "$(shorten $(get_var rocksdb_block_size "$variables_file") 0)"
    name_val "Bytes Per Sync" "$(shorten $(get_var rocksdb_bytes_per_sync "$variables_file") 0)"
    name_val "Compaction Seq Deletes " "$(shorten $(get_var rocksdb_compaction_sequential_deletes "$variables_file") 0)"
    name_val "Compaction Seq Deletes Count SD" "$(get_var rocksdb_compaction_sequential_deletes_count_sd "$variables_file")"
    name_val "Compaction Seq Deletes Window" "$(shorten $(get_var rocksdb_compaction_sequential_deletes_window "$variables_file") 0)"
    name_val "Default CF Options" "$(get_var rocksdb_default_cf_options "$variables_file")"
    name_val "Max Background Jobs" "$(shorten $(get_var rocksdb_max_background_jobs "$variables_file") 0)"
    name_val "Max Block Cache Size" "$(shorten $(get_var rocksdb_max_block_cache_size "$variables_file") 0)"
    name_val "Max Block Size" "$(shorten $(get_var rocksdb_max_block_size "$variables_file") 0)"
    name_val "Max Open Files" "$(shorten $(get_var rocksdb_max_open_files "$variables_file") 0)"
    name_val "Max Total Wal Size" "$(shorten $(get_var rocksdb_max_total_wal_size "$variables_file") 0)"
    name_val "Rate Limiter Bytes Per Second" "$(shorten $(get_var rocksdb_rate_limiter_bytes_per_sec "$variables_file") 0)"
    name_val "Rate Limiter Bytes Per Sync" "$(shorten $(get_var rocksdb_bytes_per_sync "$variables_file") 0)"
    name_val "Rate Limiter Wal Bytes Per Sync" "$(shorten $(get_var rocksdb_wal_bytes_per_sync "$variables_file") 0)"
    name_val "Table Cache NumHardBits" "$(shorten $(get_var rocksdb_table_cache_numshardbits "$variables_file") 0)"
    name_val "Wal Bytes per Sync" "$(shorten $(get_var rocksdb_wal_bytes_per_sync "$variables_file") 0)"
}

section_noteworthy_variables () {
   local file="$1"

   [ -e "$file" ] || return

   name_val "Auto-Inc Incr/Offset" "$(get_var auto_increment_increment "$file")/$(get_var auto_increment_offset "$file")"
   for v in \
      default_storage_engine flush_time init_connect init_file sql_mode;
   do
      name_val "${v}" "$(get_var ${v} "$file")"
   done
   for v in \
      join_buffer_size sort_buffer_size read_buffer_size read_rnd_buffer_size \
      bulk_insert_buffer max_heap_table_size tmp_table_size \
      max_allowed_packet thread_stack;
   do
      name_val "${v}" "$(shorten $(get_var ${v} "$file") 0)"
   done
   for v in log log_error log_warnings log_slow_queries \
         log_queries_not_using_indexes log_slave_updates;
   do
      name_val "${v}" "$(get_var ${v} "$file")"
   done
}

_semi_sync_stats_for () {
   local target="$1"
   local file="$2"

   [ -e "$file" ] || return

   local semisync_status="$(get_var "Rpl_semi_sync_${target}_status" "${file}" )"
   local semisync_trace="$(get_var "rpl_semi_sync_${target}_trace_level" "${file}")"

   local trace_extra=""
   if [ -n "${semisync_trace}" ]; then
      if [ $semisync_trace -eq 1 ]; then
         trace_extra="general (for example, time function failures) "
      elif [ $semisync_trace -eq 16 ]; then
         trace_extra="detail (more verbose information) "
      elif [ $semisync_trace -eq 32 ]; then
         trace_extra="net wait (more information about network waits)"
      elif [ $semisync_trace -eq 64 ]; then
         trace_extra="function (information about function entry and exit)"
      else
         trace_extra="Unknown setting"
      fi
   fi
   
   name_val "${target} semisync status" "${semisync_status}"
   name_val "${target} trace level" "${semisync_trace}, ${trace_extra}"

   if [ "${target}" = "master" ]; then
      name_val "${target} timeout in milliseconds" \
               "$(get_var "rpl_semi_sync_${target}_timeout" "${file}")"
      name_val "${target} waits for slaves"        \
               "$(get_var "rpl_semi_sync_${target}_wait_no_slave" "${file}")"

      _d "Prepend Rpl_semi_sync_master_ to the following"
      for v in                                              \
         clients net_avg_wait_time net_wait_time net_waits  \
         no_times no_tx timefunc_failures tx_avg_wait_time  \
         tx_wait_time tx_waits wait_pos_backtraverse        \
         wait_sessions yes_tx;
      do
         name_val "${target} ${v}" \
                  "$( get_var "Rpl_semi_sync_master_${v}" "${file}" )"
      done
   fi
}

noncounters_pattern () {
   local noncounters_pattern=""

   for var in Compression Delayed_insert_threads Innodb_buffer_pool_pages_data \
      Innodb_buffer_pool_pages_dirty Innodb_buffer_pool_pages_free \
      Innodb_buffer_pool_pages_latched Innodb_buffer_pool_pages_misc \
      Innodb_buffer_pool_pages_total Innodb_data_pending_fsyncs \
      Innodb_data_pending_reads Innodb_data_pending_writes \
      Innodb_os_log_pending_fsyncs Innodb_os_log_pending_writes \
      Innodb_page_size Innodb_row_lock_current_waits Innodb_row_lock_time_avg \
      Innodb_row_lock_time_max Key_blocks_not_flushed Key_blocks_unused \
      Key_blocks_used Last_query_cost Max_used_connections Ndb_cluster_node_id \
      Ndb_config_from_host Ndb_config_from_port Ndb_number_of_data_nodes \
      Not_flushed_delayed_rows Open_files Open_streams Open_tables \
      Prepared_stmt_count Qcache_free_blocks Qcache_free_memory \
      Qcache_queries_in_cache Qcache_total_blocks Rpl_status \
      Slave_open_temp_tables Slave_running Ssl_cipher Ssl_cipher_list \
      Ssl_ctx_verify_depth Ssl_ctx_verify_mode Ssl_default_timeout \
      Ssl_session_cache_mode Ssl_session_cache_size Ssl_verify_depth \
      Ssl_verify_mode Ssl_version Tc_log_max_pages_used Tc_log_page_size \
      Threads_cached Threads_connected Threads_running \
      Uptime_since_flush_status;
   do
      if [ -z "${noncounters_pattern}" ]; then
         noncounters_pattern="${var}"
      else
         noncounters_pattern="${noncounters_pattern}\|${var}"
      fi
   done
   echo $noncounters_pattern
}

section_mysqld () {
   local executables_file="$1"
   local variables_file="$2"

   [ -e "$executables_file" -a -e "$variables_file" ] || return

   section "MariaDB Executable"
   local i=1;
   while read executable; do
      name_val "Path to executable" "$executable"
      name_val "Has symbols" "$( get_var "pt-summary-internal-mysqld_executable_${i}" "$variables_file" )"
      i=$(($i + 1))
   done < "$executables_file"
}

section_slave_hosts () {
   local slave_hosts_file="$1"

   [ -e "$slave_hosts_file" ] || return

   section "Replicas"
   if [ -s "$slave_hosts_file" ]; then
       cat "$slave_hosts_file"
   else
       echo "No slaves found"
   fi
}

section_mysql_files () {
   local variables_file="$1"

   section "MariaDB Files"
   for file_name in pid_file slow_query_log_file general_log_file log_error; do
      local file="$(get_var "${file_name}" "$variables_file")"
      local name_out="$(echo "$file_name" | sed 'y/[a-z]/[A-Z]/')"
      if [ -e "${file}" ]; then
         name_val "$name_out" "$file"
         name_val "${name_out} Size" "$(du "$file" | awk '{print $1}')"
      else
         name_val "$name_out" "(does not exist)"
      fi
   done
}

section_mariadb_galera_cluster () {
   local mysql_var="$1"
   local mysql_status="$2"

   name_val "Cluster Name"    "$(get_var "wsrep_cluster_name" "$mysql_var")"
   name_val "Cluster Address" "$(get_var "wsrep_cluster_address" "$mysql_var")"
   name_val "Cluster Size"    "$(get_var "wsrep_cluster_size" "$mysql_status")"
   name_val "Cluster Nodes"   "$(get_var "wsrep_incoming_addresses" "$mysql_status")"

   name_val "Node Name"       "$(get_var "wsrep_node_name" "$mysql_var")"
   name_val "Node Status"     "$(get_var "wsrep_cluster_status" "$mysql_status")"

   name_val "SST Method"      "$(get_var "wsrep_sst_method" "$mysql_var")"
   name_val "Slave Threads"   "$(get_var "wsrep_slave_threads" "$mysql_var")"
   
   name_val "Ignore Split Brain" "$( parse_wsrep_provider_options "pc.ignore_sb" "$mysql_var" )"
   name_val "Ignore Quorum" "$( parse_wsrep_provider_options "pc.ignore_quorum" "$mysql_var" )"
   
   name_val "gcache Size"      "$( parse_wsrep_provider_options "gcache.size" "$mysql_var" )"
   name_val "gcache Directory" "$( parse_wsrep_provider_options "gcache.dir" "$mysql_var" )"
   name_val "gcache Name"      "$( parse_wsrep_provider_options "gcache.name" "$mysql_var" )"
}

parse_wsrep_provider_options () {
   local looking_for="$1"
   local mysql_var_file="$2"

   grep wsrep_provider_options "$mysql_var_file" \
   | perl -Mstrict -le '
      my $provider_opts = scalar(<STDIN>);
      my $looking_for   = $ARGV[0];
      my %opts          = $provider_opts =~ /(\S+)\s*=\s*(\S*)(?:;|$)/g;
      print $opts{$looking_for};
   ' "$looking_for"
}

report_jemalloc_enabled() {
  local JEMALLOC_STATUS=''
  local GENERAL_JEMALLOC_STATUS=0
  local JEMALLOC_LOCATION=''

  for pid in $(pidof mysqld); do
     grep -qc jemalloc /proc/${pid}/environ || ldd $(which mysqld) 2>/dev/null | grep -qc jemalloc
     jemalloc_status=$?
     if [ $jemalloc_status = 1 ]; then
       echo "jemalloc is not enabled in mariadb config for process with id ${pid}" 
     else
       echo "jemalloc enabled in mariadb config for process with id ${pid}"
       GENERAL_JEMALLOC_STATUS=1
     fi
  done

  if [ $GENERAL_JEMALLOC_STATUS -eq 1 ]; then
     JEMALLOC_LOCATION=$(find /usr/lib64/ /usr/lib/x86_64-linux-gnu /usr/lib -name "libjemalloc.*" 2>/dev/null | head -n 1)
     if [ -z "$JEMALLOC_LOCATION" ]; then
       echo "Jemalloc library not found"
     else
       echo "Using jemalloc from $JEMALLOC_LOCATION"
     fi
  fi
 
}

report_mysql_summary () {
   local dir="$1"

   local NAME_VAL_LEN=25


   section "MariaDB Server Summary Report"
   name_val "System time" "`date -u +'%F %T UTC'` (local TZ: `date +'%Z %z'`)"
   section "Instances"
   parse_mysqld_instances "$dir/mysqld-instances" "$dir/mariadb-variables"

   section_mysqld "$dir/mysqld-executables" "$dir/mariadb-variables"

   section_slave_hosts "$dir/mariadb-slave-hosts"
   local user="$(get_var "pt-summary-internal-user" "$dir/mariadb-variables")"
   local port="$(get_var port "$dir/mariadb-variables")"
   local now="$(get_var "pt-summary-internal-now" "$dir/mariadb-variables")"
   section "Report On Port ${port}"
   name_val User "${user}"
   name_val Time "${now} ($(get_mysql_timezone "$dir/mariadb-variables"))"
   name_val Hostname "$(get_var hostname "$dir/mariadb-variables")"
   get_mysql_version "$dir/mariadb-variables"

   local uptime="$(get_var Uptime "$dir/mariadb-status")"
   local current_time="$(get_var "pt-summary-internal-current_time" "$dir/mariadb-variables")"
   name_val Started "$(get_mysql_uptime "${uptime}" "${current_time}")"

   local num_dbs="$(grep -c . "$dir/mariadb-databases")"
   name_val Databases "${num_dbs}"
   name_val Datadir "$(get_var datadir "$dir/mariadb-variables")"

   local fuzz_procs=$(fuzz $(get_var Threads_connected "$dir/mariadb-status"))
   local fuzz_procr=$(fuzz $(get_var Threads_running "$dir/mariadb-status"))
   name_val Processes "${fuzz_procs} connected, ${fuzz_procr} running"

   local slave=""
   if [ -s "$dir/mariadb-slave" ]; then slave=""; else slave="not "; fi
   local slavecount=$(grep -c 'Binlog Dump' "$dir/mariadb-processlist")
   name_val Replication "Is ${slave}a slave, has ${slavecount} slaves connected"


   local pid_file="$(get_var "pid_file" "$dir/mariadb-variables")"
   local PID_EXISTS=""
   if [ "$( get_var "pt-summary-internal-pid_file_exists" "$dir/mariadb-variables" )" ]; then
      PID_EXISTS="(exists)"
   else
      PID_EXISTS="(does not exist)"
   fi
   name_val Pidfile "${pid_file} ${PID_EXISTS}"

   section "Processlist"
   summarize_processlist "$dir/mariadb-processlist"

   section "Status Counters (Wait ${OPT_SLEEP} Seconds)"
   wait
   local noncounters_pattern="$(noncounters_pattern)"
   format_status_variables "$dir/mariadb-status-defer" | grep -v "${noncounters_pattern}"

   section "Table cache"
   local open_tables=$(get_var "Open_tables" "$dir/mariadb-status")
   local table_cache=$(get_table_cache "$dir/mariadb-variables")
   name_val Size  $table_cache
   name_val Usage "$(fuzzy_pct ${open_tables} ${table_cache})"

   section "Key MariaDB Server features"
   section_mariadb_server_features "$dir/mariadb-variables"

   section "MariaDB Galera Cluster"
   local has_wsrep=$($CMD_MYSQL $EXT_ARGV -ss -e 'show session variables like "%wsrep_on%";' | cut -f2 | grep -i "on")
   if [ -n "${has_wsrep:-""}" ]; then
      if [ "${has_wsrep:-""}" = "ON" ]; then
         section_mariadb_galera_cluster "$dir/mariadb-variables" "$dir/mariadb-status"
      else
         name_val "wsrep_on" "OFF"
      fi
   fi

   section "Plugins"
   name_val "InnoDB compression" "$(get_plugin_status "$dir/mariadb-plugins" "INNODB_CMP")"

   local has_query_cache=$(get_var have_query_cache "$dir/mariadb-variables")
   if [ "$has_query_cache" = 'YES' ]; then
      section "Query cache"
      local query_cache_size=$(get_var query_cache_size "$dir/mariadb-variables")
      local used=$(( ${query_cache_size} - $(get_var Qcache_free_memory "$dir/mariadb-status") ))
      local hrat=$(fuzzy_pct $(get_var Qcache_hits "$dir/mariadb-status") $(get_var Qcache_inserts "$dir/mariadb-status"))
      name_val query_cache_type $(get_var query_cache_type "$dir/mariadb-variables")
      name_val Size "$(shorten ${query_cache_size} 1)"
      name_val Usage "$(fuzzy_pct ${used} ${query_cache_size})"
      name_val HitToInsertRatio "${hrat}"
   fi

   local semisync_enabled_master="$(get_var "rpl_semi_sync_master_enabled" "$dir/mariadb-variables")"
   if [ -n "${semisync_enabled_master}" ]; then
      section "Semisynchronous Replication"
      if [ "$semisync_enabled_master" = "OFF" -o "$semisync_enabled_master" = "0" -o -z "$semisync_enabled_master" ]; then
         name_val "Primary" "Disabled"
      else
         _semi_sync_stats_for "master" "$dir/mariadb-variables"
      fi
      local semisync_enabled_slave="$(get_var rpl_semi_sync_slave_enabled "$dir/mariadb-variables")"
      if    [ "$semisync_enabled_slave" = "OFF" -o "$semisync_enabled_slave" = "0" -o -z "$semisync_enabled_slave" ]; then
         name_val "Replica" "Disabled"
      else
         _semi_sync_stats_for "slave" "$dir/mariadb-variables"
      fi
   fi

   section "Schema"
   if [ -s "$dir/mysqldump" ] \
      && grep 'CREATE TABLE' "$dir/mysqldump" >/dev/null 2>&1; then
         format_overall_db_stats "$dir/mysqldump"
   elif [ ! -e "$dir/mysqldump" -a "$OPT_READ_SAMPLES" ]; then
      echo "Skipping schema analysis because --read-samples $dir/mysqldump " \
         "does not exist"
   elif [ -z "$OPT_DATABASES" -a -z "$OPT_ALL_DATABASES" ]; then
      echo "Specify --databases or --all-databases to dump and summarize schemas"
   else
      echo "Skipping schema analysis due to apparent error in dump file"
   fi

   section "Noteworthy Technologies"
   if [ -s "$dir/mysqldump" ]; then
      if grep FULLTEXT "$dir/mysqldump" > /dev/null; then
         name_val "Full Text Indexing" "Yes"
      else
         name_val "Full Text Indexing" "No"
      fi
      if grep 'GEOMETRY\|POINT\|LINESTRING\|POLYGON' "$dir/mysqldump" > /dev/null; then
         name_val "Geospatial Types" "Yes"
      else
         name_val "Geospatial Types" "No"
      fi
      if grep 'FOREIGN KEY' "$dir/mysqldump" > /dev/null; then
         name_val "Foreign Keys" "Yes"
      else
         name_val "Foreign Keys" "No"
      fi
      if grep 'PARTITION BY' "$dir/mysqldump" > /dev/null; then
         name_val "Partitioning" "Yes"
      else
         name_val "Partitioning" "No"
      fi
      if grep -e 'ENGINE=InnoDB.*ROW_FORMAT' \
         -e 'ENGINE=InnoDB.*KEY_BLOCK_SIZE' "$dir/mysqldump" > /dev/null; then
         name_val "InnoDB Compression" "Yes"
      else
         name_val "InnoDB Compression" "No"
      fi
   fi
   local ssl="$(get_var Ssl_accepts "$dir/mariadb-status")"
   if [ -n "$ssl" -a "${ssl:-0}" -gt 0 ]; then
      name_val "SSL" "Yes"
   else
      name_val "SSL" "No"
   fi
   local lock_tables="$(get_var Com_lock_tables "$dir/mariadb-status")"
   if [ -n "$lock_tables" -a "${lock_tables:-0}" -gt 0 ]; then
      name_val "Explicit LOCK TABLES" "Yes"
   else
      name_val "Explicit LOCK TABLES" "No"
   fi
   local delayed_insert="$(get_var Delayed_writes "$dir/mariadb-status")"
   if [ -n "$delayed_insert" -a "${delayed_insert:-0}" -gt 0 ]; then
      name_val "Delayed Insert" "Yes"
   else
      name_val "Delayed Insert" "No"
   fi
   local xat="$(get_var Com_xa_start "$dir/mariadb-status")"
   if [ -n "$xat" -a "${xat:-0}" -gt 0 ]; then
      name_val "XA Transactions" "Yes"
   else
      name_val "XA Transactions" "No"
   fi
   local cs_cluster="$(get_var "infinidb_local_query" "$dir/mariadb-status")"
   if [ -n "$cs_cluster" -a "${cs_cluster:-0}" -gt 0 ]; then
      name_val "ColumnStore Cluster" "Yes"
   else
      name_val "ColumnStore Cluster" "No"
   fi
   local prep=$(( $(get_var "Com_stmt_prepare" "$dir/mariadb-status") + $(get_var "Com_prepare_sql" "$dir/mariadb-status") ))
   if [ "${prep}" -gt 0 ]; then
      name_val "Prepared Statements" "Yes"
   else
      name_val "Prepared Statements" "No"
   fi
   local prep_count="$(get_var Prepared_stmt_count "$dir/mariadb-status")"
   if [ "${prep_count}" ]; then
      name_val "Prepared statement count" "${prep_count}"
   fi

   section "InnoDB"
   local have_innodb="$(get_var "have_innodb" "$dir/mariadb-variables")"
   local innodb_version="$(get_var "innodb_version" "$dir/mariadb-variables")"
   if [ "${have_innodb}" = "YES" ] || [ -n "${innodb_version}" ]; then
      section_innodb "$dir/mariadb-variables" "$dir/mariadb-status"

      if [ -s "$dir/innodb-status" ]; then
         format_innodb_status "$dir/innodb-status"
      fi
   fi

   local has_rocksdb=$($CMD_MYSQL $EXT_ARGV -ss -e 'SHOW ENGINES' 2>/dev/null | grep -i 'rocksdb')
   if [ ! -z "$has_rocksdb" ]; then
       section "RocksDB"
       section_rocksdb "$dir/mariadb-variables" "$dir/mariadb-status"
   fi

   if [ -s "$dir/cs-status" ]; then
       section "ColumnStore"
       format_cs_status "$dir/cs-status"
   fi

   section "MyISAM"
   section_myisam "$dir/mariadb-variables" "$dir/mariadb-status"

   section "Aria"
   section_aria "$dir/mariadb-variables" "$dir/mariadb-status"

   section "Security"
   local users="$( format_users "$dir/mariadb-users" )"
   name_val "Users" "${users}"
   name_val "Old Passwords" "$(get_var old_passwords "$dir/mariadb-variables")"

   if [ -s "$dir/mariadb-roles" ]; then
       section "Roles"
       format_mysql_roles "$dir/mariadb-roles"
   fi

   if [[ ! -z "$OPT_LIST_ENCRYPTED_TABLES" ]]; then 
       section "Encryption"
       local keyring_plugins="$(collect_keyring_plugins)"
       local encrypted_tables=""
       local encrypted_tablespaces=""
       if [ "${OPT_LIST_ENCRYPTED_TABLES}" = 'yes' ]; then 
           encrypted_tables="$(collect_encrypted_tables)"
           encrypted_tablespaces="$(collect_encrypted_tablespaces)"
       fi
   fi

   format_keyring_plugins "$keyring_plugins" "$encrypted_tables"
   format_encrypted_tables "$encrypted_tables"
   format_encrypted_tablespaces "$encrypted_tablespaces"

   section "Binary Logging"

   if    [ -s "$dir/mariadb-master-logs" ] \
      || [ -s "$dir/mariadb-master-status" ]; then
      summarize_binlogs "$dir/mariadb-master-logs"
      local format="$(get_var binlog_format "$dir/mariadb-variables")"
      name_val binlog_format "${format:-STATEMENT}"
      name_val expire_logs_days "$(get_var expire_logs_days "$dir/mariadb-variables")"
      name_val sync_binlog "$(get_var sync_binlog "$dir/mariadb-variables")"
      name_val server_id "$(get_var server_id "$dir/mariadb-variables")"
      format_binlog_filters "$dir/mariadb-master-status"
   fi


   section "Noteworthy Variables"
   section_noteworthy_variables "$dir/mariadb-variables"

   section "Configuration File"
   local cnf_file="$(get_var "pt-summary-internal-Config_File_path" "$dir/mariadb-variables")"

   if [ -n "${cnf_file}" ]; then
      name_val "Config File" "${cnf_file}"
      pretty_print_cnf_file "$dir/mariadb-config-file"
   else
      name_val "Config File" "Cannot autodetect or find, giving up"
   fi

   section "Memory management library"
   report_jemalloc_enabled

   section "The End"
}

# ###########################################################################
# End report_mysql_info package
# ###########################################################################
