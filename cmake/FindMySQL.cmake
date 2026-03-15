# - Find mysqlclient / MariaDB client library
#
# This module defines:
#   MYSQL_FOUND
#   MYSQL_INCLUDE_DIR
#   MYSQL_LIBRARY
#   MYSQL_LIBRARIES
#   MySQL::Client (imported target)

if(DEFINED MYSQL_INCLUDE_DIR)
  set(MYSQL_FIND_QUIETLY TRUE)
endif()

include(FindPackageHandleStandardArgs)

# Try pkg-config first (mysqlclient / libmariadb)
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(PC_MYSQL QUIET mysqlclient libmariadb)
endif()

find_path(MYSQL_INCLUDE_DIR
  NAMES mysql.h
  HINTS ${PC_MYSQL_INCLUDEDIR} ${PC_MYSQL_INCLUDE_DIRS}
  PATHS
    /usr/include/mysql
    /usr/local/include/mysql
    /opt/homebrew/include/mysql
)

# mysqlclient_r is obsolete; keep as fallback for legacy systems.
set(_MYSQL_CANDIDATE_LIBS mysqlclient mariadb mariadbclient mysqlclient_r)
find_library(MYSQL_LIBRARY
  NAMES ${_MYSQL_CANDIDATE_LIBS}
  HINTS ${PC_MYSQL_LIBDIR} ${PC_MYSQL_LIBRARY_DIRS}
  PATHS
    /usr/lib
    /usr/local/lib
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu
    /opt/homebrew/lib
  PATH_SUFFIXES mysql mariadb
)

set(MYSQL_LIBRARIES ${MYSQL_LIBRARY})

find_package_handle_standard_args(MySQL
  REQUIRED_VARS MYSQL_INCLUDE_DIR MYSQL_LIBRARY
  FAIL_MESSAGE "Could NOT find MySQL/MariaDB client library"
)

if(MYSQL_FOUND AND NOT TARGET MySQL::Client)
  add_library(MySQL::Client UNKNOWN IMPORTED)
  set_target_properties(MySQL::Client PROPERTIES
    IMPORTED_LOCATION "${MYSQL_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${MYSQL_INCLUDE_DIR}"
  )
endif()

mark_as_advanced(MYSQL_LIBRARY MYSQL_INCLUDE_DIR)
