#' Set Database Connection Information
#'
#' Store database connection parameters as environment variables
#' for later use by [set_db_conn()]. If the `port` argument is omitted,
#' a default port will be automatically assigned based on the database type:
#' \itemize{
#'   \item MariaDB / MySQL: 3306
#'   \item PostgreSQL: 5432
#'   \item SQLite / ODBC: no port used
#' }
#'
#' @param driver Character string specifying the DB type.
#'   One of `"mariadb"`, `"mysql"`, `"postgres"`, `"sqlite"`, `"odbc"`.
#' @param host Database host name or IP address.
#' @param dbname Database name (ignored for SQLite if `filepath` is used).
#' @param user Username for authentication.
#' @param password Password for authentication.
#' @param port Numeric; port number. If missing, a default is chosen by DB type.
#' @param dsn For ODBC connections, a DSN string if available.
#' @param filepath For SQLite, path to the `.sqlite` file.
#'
#' @return Invisibly returns `TRUE` (for side effect).
#' @export
set_db_conn_info <- function(driver = c("mariadb", "mysql", "postgres", "sqlite", "odbc"),
                             host = "",
                             dbname = "",
                             user = "",
                             password = "",
                             port = NULL,
                             dsn = "",
                             filepath = "") {
  driver <- match.arg(driver)

  # --------------------------------------------------------------------
  # Auto-assign default port if not provided
  # --------------------------------------------------------------------
  if (is.null(port) || is.na(port) || port == "") {
    port <- switch(driver,
                   mariadb  = 3306L,
                   mysql    = 3306L,
                   postgres = 5432L,
                   sqlite   = NA_integer_,
                   odbc     = NA_integer_)
  }

  # --------------------------------------------------------------------
  # Store connection settings as environment variables
  # --------------------------------------------------------------------
  Sys.setenv(
    MINTDB_DRIVER   = driver,
    MINTDB_HOST     = host,
    MINTDB_DBNAME   = dbname,
    MINTDB_USER     = user,
    MINTDB_PASSWORD = password,
    MINTDB_PORT     = ifelse(is.na(port), "", as.integer(port)),
    MINTDB_DSN      = dsn,
    MINTDB_FILEPATH = filepath
  )

  invisible(TRUE)
}

# ---------------------------------------------------------------------
# Internal helper: return DBI driver instance based on driver name
# ---------------------------------------------------------------------
.mintdb_drv <- function(driver) {
  switch(
    driver,
    mariadb  = RMariaDB::MariaDB(),
    mysql    = RMariaDB::MariaDB(),  # MySQL shares same RMariaDB driver
    postgres = RPostgres::Postgres(),
    sqlite   = RSQLite::SQLite(),
    odbc     = odbc::odbc(),
    stop(sprintf("Unsupported driver: %s", driver))
  )
}

#' Establish Database Connection (and Driver-Specific Wrappers)
#'
#' Create a database connection (or a connection pool when available) using
#' parameters previously set by [set_db_conn_info()]. This page documents
#' the core connector `set_db_conn()` and its driver-specific wrapper helpers:
#'
#' \itemize{
#'   \item \code{set_mariadb_conn()} — sets driver to `"mariadb"`
#'   \item \code{set_mysql_conn()} — sets driver to `"mysql"` (uses RMariaDB)
#'   \item \code{set_postgres_conn()} — sets driver to `"postgres"`
#'   \item \code{set_sqlite_conn()} — sets driver to `"sqlite"`
#'   \item \code{set_odbc_conn()} — sets driver to `"odbc"`
#' }
#'
#' If `use_pool = TRUE` and the \pkg{pool} package is installed, a pool
#' is created via [pool::dbPool()]. Otherwise, a plain DBI connection is
#' created via [DBI::dbConnect()]. The active connection (or pool) is stored
#' in the internal environment `.MINTDB_ENV` as `.MINTDB_CONN`.
#'
#' @param use_pool Logical; use a connection pool if available. Default `TRUE`
#'   (except for SQLite wrappers where pooling typically provides no benefit).
#' @param ... Additional arguments forwarded to [DBI::dbConnect()] or
#'   [pool::dbPool()], depending on `use_pool`.
#'
#' @return A DBI connection or a `Pool` object (also saved in `.MINTDB_ENV`).
#'
#' @name set_db_conn
#' @export
set_db_conn <- function(use_pool = TRUE, ...) {
  # -------------------------------------------------------------------
  # Close previous connection if exists
  # -------------------------------------------------------------------
  if (exists(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)) {
    old <- get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)
    if (!is.null(old)) {
      try({
        if (inherits(old, "Pool")) pool::poolClose(old)
        else if (DBI::dbIsValid(old)) DBI::dbDisconnect(old)
      }, silent = TRUE)
    }
    rm(".MINTDB_CONN", envir = .MINTDB_ENV)
  }

  # -------------------------------------------------------------------
  # Load connection parameters from environment
  # -------------------------------------------------------------------
  drv_name <- Sys.getenv("MINTDB_DRIVER", "mariadb")
  host     <- Sys.getenv("MINTDB_HOST")
  dbname   <- Sys.getenv("MINTDB_DBNAME", "")
  user     <- Sys.getenv("MINTDB_USER", "")
  password <- Sys.getenv("MINTDB_PASSWORD", "")
  port_chr <- Sys.getenv("MINTDB_PORT", "")
  dsn      <- Sys.getenv("MINTDB_DSN", "")
  filepath <- Sys.getenv("MINTDB_FILEPATH", "")
  port     <- suppressWarnings(as.integer(port_chr))

  # -------------------------------------------------------------------
  # Prompt for password if missing
  # -------------------------------------------------------------------
  if (!nzchar(password)) {
    if (requireNamespace("askpass", quietly = TRUE)) {
      password <- askpass::askpass("DB Password: ")
    } else {
      cat("DB Password: "); password <- readline()
    }
  }

  # -------------------------------------------------------------------
  # Build argument list by driver type
  # -------------------------------------------------------------------
  args <- list()
  if (drv_name %in% c("mariadb", "mysql", "postgres")) {
    args <- list(dbname = dbname, host = host, user = user, password = password)
    if (!is.na(port) && port > 0) args$port <- port
  } else if (drv_name == "sqlite") {
    args <- list(dbname = if (nzchar(filepath)) filepath else dbname)
  } else if (drv_name == "odbc") {
    # ODBC can use DSN or explicit parameters
    if (nzchar(dsn)) {
      args <- list(dsn = dsn, uid = user, pwd = password)
    } else {
      args <- list(UID = user, PWD = password)
      if (nzchar(dbname)) args$Database <- dbname
      if (nzchar(host))   args$Server   <- host
      if (!is.na(port) && port > 0) args$Port <- port
    }
  }

  # -------------------------------------------------------------------
  # Choose DBI driver object
  # -------------------------------------------------------------------
  driver_obj <- .mintdb_drv(drv_name)

  # -------------------------------------------------------------------
  # Create connection or pool
  # -------------------------------------------------------------------
  if (use_pool && requireNamespace("pool", quietly = TRUE)) {
    message("Using connection pool...")
    conn <- do.call(pool::dbPool, c(list(drv = driver_obj), args, list(...)))
  } else {
    conn <- do.call(DBI::dbConnect, c(list(drv = driver_obj), args, list(...)))
  }

  # -------------------------------------------------------------------
  # Optional initialization per DB type
  # -------------------------------------------------------------------
  if (drv_name %in% c("mariadb", "mysql")) {
    DBI::dbExecute(conn, "SET NAMES 'utf8mb4'")
  }

  # Store connection object in internal environment
  assign(".MINTDB_CONN", conn, envir = .MINTDB_ENV)
  conn
}

#' @rdname set_db_conn
#' @export
set_mariadb_conn <- function(use_pool = TRUE, ...) {
  Sys.setenv(MINTDB_DRIVER = "mariadb")
  set_db_conn(use_pool = use_pool, ...)
}

#' @rdname set_db_conn
#' @export
set_mysql_conn <- function(use_pool = TRUE, ...) {
  Sys.setenv(MINTDB_DRIVER = "mysql")
  set_db_conn(use_pool = use_pool, ...)
}

#' @rdname set_db_conn
#' @export
set_postgres_conn <- function(use_pool = TRUE, ...) {
  Sys.setenv(MINTDB_DRIVER = "postgres")
  set_db_conn(use_pool = use_pool, ...)
}

#' @rdname set_db_conn
#' @export
set_sqlite_conn <- function(use_pool = FALSE, ...) {
  Sys.setenv(MINTDB_DRIVER = "sqlite")
  set_db_conn(use_pool = use_pool, ...)
}

#' @rdname set_db_conn
#' @export
set_odbc_conn <- function(use_pool = TRUE, ...) {
  Sys.setenv(MINTDB_DRIVER = "odbc")
  set_db_conn(use_pool = use_pool, ...)
}

#' Retrieve the Active Database Connection
#'
#' Returns the currently active database connection or connection pool
#' stored in the internal environment `.MINTDB_ENV`.
#' This function is primarily intended for internal use or for advanced
#' users who need direct access to the underlying connection object.
#'
#' @details
#' The returned object will be either:
#' \itemize{
#'   \item a `DBIConnection` object, if the connection was established
#'         using [DBI::dbConnect()];
#'   \item or a `Pool` object, if connection pooling was enabled through
#'         [pool::dbPool()].
#' }
#'
#' The function automatically checks that a valid connection exists
#' by calling [has_db_conn()]. If no active connection is found,
#' an error is raised.
#'
#' @return A live `DBIConnection` or a `Pool` object.
#'
#' @seealso [set_db_conn()], [set_db_disconn()], [has_db_conn()]
#'
#' @examples
#' \dontrun{
#' set_db_conn_info(driver = "sqlite", filepath = "data/test.sqlite")
#' set_db_conn()
#'
#' con <- get_db_conn()
#' DBI::dbListTables(con)
#'
#' set_db_disconn()
#' }
#'
#' @export
get_db_conn <- function() {
  has_db_conn()
  get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)
}

#' Disconnect Active Database Connection
#'
#' Safely close the active database connection or pool stored in `.MINTDB_ENV`.
#' If no connection exists, silently return.
#'
#' @return Invisibly returns `TRUE`.
#'
#' @export
set_db_disconn <- function() {
  if (exists(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)) {
    conn <- get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)
    if (!is.null(conn)) {
      try({
        if (inherits(conn, "Pool")) pool::poolClose(conn)
        else if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
      }, silent = TRUE)
    }
    rm(".MINTDB_CONN", envir = .MINTDB_ENV)
  }
  invisible(TRUE)
}

#' Check for an Active Database Connection
#'
#' Verify that a database connection (or pool) exists and is still valid.
#'
#' @return Logical `TRUE` if the connection is active; otherwise an error is thrown.
#'
#' @export
has_db_conn <- function() {
  if (!exists(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE))
    stop("No active database connection found. Call set_db_conn() first.")

  conn <- get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)
  ok <- try(DBI::dbIsValid(conn), silent = TRUE)

  if (inherits(ok, "try-error") || !isTRUE(ok))
    stop("Database connection (or pool) is invalid or closed. Reconnect with set_db_conn().")

  TRUE
}
