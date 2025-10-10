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
#' @section Persistent setup via `.Renviron`:
#' While `set_db_conn_info()` is convenient for one-off sessions, you can persist
#' your settings using environment variables in `~/.Renviron` (or a project-local `.Renviron`).
#'
#' 1. Open your `.Renviron`:
#'    ```r
#'    usethis::edit_r_environ()
#'    ```
#'
#' 2. Add the variables (example: PostgreSQL):
#'    ```ini
#'    MINTDB_DRIVER=postgres
#'    MINTDB_HOST=localhost
#'    MINTDB_DBNAME=app
#'    MINTDB_USER=postgres
#'    MINTDB_PASSWORD=secret
#'    MINTDB_PORT=5432
#'    ```
#'
#'    For SQLite:
#'    ```ini
#'    MINTDB_DRIVER=sqlite
#'    MINTDB_FILEPATH=data/app.sqlite
#'    ```
#'
#' 3. Restart R, then simply call:
#'    ```r
#'    .rs.restartR()
#'    set_db_conn()
#'    ```
#'
#' *Security tip:* do **not** commit `.Renviron` to version control. Prefer environment
#' variables for secrets. For advanced, profile-based setups, consider using a YAML
#' file and a loader (e.g., `load_db_conn_info_yaml("mintdb.yml", profile = "prod")`).
#'
#' @seealso
#' [DBI::dbConnect()], [pool::dbPool()], [askpass::askpass()], [usethis::edit_r_environ()]
#'
#' @keywords internal
#' @importFrom askpass askpass
#' @importFrom DBI dbBegin dbCommit dbConnect dbDisconnect dbIsValid dbRollback
#' @importFrom pool dbPool poolCheckout poolClose poolReturn
"_PACKAGE"
