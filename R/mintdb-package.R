#' @description
#' **mintdb** (Minimal Integration Toolkit for Databases) provides
#' a unified and lightweight interface for connecting to multiple
#' database backends such as MariaDB, MySQL, PostgreSQL, SQLite, and ODBC.
#'
#' It wraps the standard [DBI] interface and optionally supports
#' connection pooling through the [pool] package.
#' Environment-based helpers allow you to define and reuse connection
#' settings easily across scripts, Shiny apps, and background services.
#'
#' @details
#' Key exported functions:
#' \itemize{
#'   \item [set_db_conn_info()] — Define and store DB credentials and connection info.
#'   \item [set_db_conn()] — Establish a connection (optionally using a pool).
#'   \item [set_db_disconn()] — Safely disconnect the active connection or pool.
#'   \item [has_db_conn()] — Check whether an active valid connection exists.
#'   \item Driver-specific helpers:
#'     [set_mariadb_conn()], [set_mysql_conn()], [set_postgres_conn()],
#'     [set_sqlite_conn()], [set_odbc_conn()].
#' }
#'
#' When the package is loaded, a private environment `.MINTDB_ENV` is created
#' to manage active connections. Upon unloading, all connections or pools are
#' automatically closed to ensure safe cleanup.
#'
#' This design makes **mintdb** suitable for persistent R sessions,
#' automated batch jobs, and reactive web apps where safe connection
#' handling is crucial.
#'
#' @seealso
#' [DBI::dbConnect()], [pool::dbPool()], [askpass::askpass()]
#'
#' @keywords internal
#' @importFrom askpass askpass
#' @importFrom DBI dbBegin dbCommit dbConnect dbDisconnect dbIsValid dbRollback
#' @importFrom pool dbPool poolCheckout poolClose poolReturn
"_PACKAGE"
