#!/usr/bin/env bash
# Menunggu container db_init (pembuat database + skema) selesai dengan sukses.
set -u
limit="${1:-900}"; waited=0
while [ "$waited" -lt "$limit" ]; do
  state=$(docker inspect -f '{{.State.Status}}' ptxyz_db_init 2>/dev/null || echo missing)
  code=$(docker inspect -f '{{.State.ExitCode}}' ptxyz_db_init 2>/dev/null || echo 1)
  if [ "$state" = "exited" ] && [ "$code" = "0" ]; then echo "db_init selesai (database & skema siap)."; exit 0; fi
  if [ "$state" = "exited" ]; then echo "db_init GAGAL (exit $code):"; docker logs --tail 20 ptxyz_db_init; exit 1; fi
  sleep 10; waited=$((waited + 10)); echo "menunggu db_init ($state) ${waited}s/${limit}s ..."
done
echo "Timeout menunggu db_init."; exit 1
