#!/usr/bin/awk -f

BEGIN {
   times = 0
   total = 0
}

/^real/ {
   gsub(/[ms]/, " ", $2)
   split($2, dur, " ")

   if (dur[1] > 0) {
      print "Function took greater than 1m. Invalid." > "/dev/stderr"
      exit 1
   }

   ++ times
   total += dur[2]

   printf "[%3d]\t%.3fs\t avg.\t%.3fs\n", times, dur[2], (total / times)
}
