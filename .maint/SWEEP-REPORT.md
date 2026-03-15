# Trojan Full Repo Sweep Report
date=2026-03-15T22:44:48+08:00
branch=maint/full-repo-sweep-v1.16.5

## Top-level dirs
.
./.git
./.github
./.maint
./cmake
./docs
./examples
./scripts
./src
./tests

## File count by dir
cmake: 1
docs: 9
examples: 5
scripts: 1
src: 33
tests: 9
.github: 2

## Risk patterns
cmake/FindMySQL.cmake:31:# mysqlclient_r is obsolete; keep as fallback for legacy systems.
cmake/FindMySQL.cmake:32:set(_MYSQL_CANDIDATE_LIBS mysqlclient mariadb mariadbclient mysqlclient_r)
src/proto/socks5address.cpp:60:                sprintf(t, "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x",
src/core/config.cpp:162:        sprintf(mdString + (i << 1), "%02x", (unsigned int)digest[i]);

## CMake minimum
1:cmake_minimum_required(VERSION 3.7.2)
