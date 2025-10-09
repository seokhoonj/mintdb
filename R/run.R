#' Run a SELECT Query and Retrieve Results
#'
#' Safely executes a SQL `SELECT` query on the active connection (or pool),
#' supporting parameter binding and optional **data.table** return.
#'
#' @param sql Character SQL statement (typically a `SELECT`).
#' @param params Optional list of parameter values to bind to `?` placeholders
#'   in `sql`. Values are bound in order. If empty, binding is skipped.
#' @param as_dt Logical; when `TRUE` and **data.table** is installed,
#'   the result is returned as a data.table. Default `FALSE`.
#'
#' @return A data.frame (or data.table if `as_dt = TRUE`).
#' @seealso [exec_db()], [set_db_conn()], [get_db_conn()], [has_db_conn()]
#'
#' @examples
#' \dontrun{
#' set_db_conn_info(driver = "sqlite", filepath = "data/test.sqlite")
#' set_db_conn()
#'
#' # No params
#' query_db("SELECT 1 AS x")
#'
#' # With params (safe)
#' query_db("SELECT * FROM users WHERE id = ? AND status = ?", params = list(42, "active"))
#'
#' # As data.table
#' query_db("SELECT * FROM users LIMIT 10", as_dt = TRUE)
#'
#' set_db_disconn()
#' }
#' @export
query_db <- function(sql, params = list(), as_dt = FALSE) {
  has_db_conn()
  con <- get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)

  # If params provided, use prepared statement + bind; else plain dbGetQuery
  if (length(params)) {
    rs <- DBI::dbSendQuery(con, sql)
    on.exit(try(DBI::dbClearResult(rs), silent = TRUE), add = TRUE)
    DBI::dbBind(rs, params)
    out <- DBI::dbFetch(rs)
  } else {
    out <- DBI::dbGetQuery(con, sql)
  }

  if (isTRUE(as_dt) && requireNamespace("data.table", quietly = TRUE)) {
    out <- data.table::as.data.table(out)
  }

  out
}

#' Execute a Non-SELECT Statement
#'
#' Executes a SQL statement that does not return a result set (e.g. `INSERT`,
#' `UPDATE`, `DELETE`, or DDL). Supports positional parameter binding.
#'
#' @param sql Character SQL statement (non-SELECT).
#' @param params Optional list of parameter values to bind to `?` placeholders
#'   in `sql`. Values are bound in order. If empty, binding is skipped.
#'
#' @return Invisibly returns an integer with the number of rows affected (when available).
#' @seealso [query_db()], [set_db_conn()], [get_db_conn()], [has_db_conn()]
#'
#' @examples
#' \dontrun{
#' set_db_conn_info(driver = "postgres", host = "localhost", dbname = "app",
#'                  user = "pg", password = "pw")
#' set_db_conn()
#'
#' # Insert with params
#' exec_db("INSERT INTO logs(message, level) VALUES (?, ?)", params = list("ok", "INFO"))
#'
#' # Update without params
#' exec_db("UPDATE users SET last_login = NOW() WHERE id = 42")
#'
#' set_db_disconn()
#' }
#' @export
exec_db <- function(sql, params = list()) {
  has_db_conn()
  con <- get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)

  # Prefer dbExecute with params when supported; otherwise use send/bind path
  if (length(params)) {
    res <- try(DBI::dbExecute(con, statement = sql, params = params), silent = TRUE)
    if (inherits(res, "try-error")) {
      st <- DBI::dbSendStatement(con, sql)
      on.exit(try(DBI::dbClearResult(st), silent = TRUE), add = TRUE)
      DBI::dbBind(st, params)
      res <- DBI::dbGetRowsAffected(st)
    }
  } else {
    res <- DBI::dbExecute(con, statement = sql)
  }

  invisible(res)
}

#' Evaluate Expressions Within a Database Transaction
#'
#' Executes one or more R expressions inside a database transaction context.
#' If an error occurs, the transaction is automatically rolled back;
#' otherwise it is committed. Works with both regular connections and pools.
#'
#' @param code Expressions to evaluate within the transaction.
#'
#' @return Invisibly returns the result of the evaluated expression(s)
#'   after a successful commit.
#'
#' @details
#' This function wraps `DBI::dbBegin()`, `DBI::dbCommit()`, and
#' `DBI::dbRollback()` with automatic error handling.
#' It is analogous to `withr::with_*()` helpers for temporary contexts.
#'
#' @examples
#' \dontrun{
#' set_db_conn_info(driver = "sqlite", filepath = "data/test.sqlite")
#' set_db_conn()
#'
#' with_db_transaction({
#'   exec_db("INSERT INTO logs(message) VALUES (?)", params = list("start"))
#'   exec_db("INSERT INTO logs(message) VALUES (?)", params = list("middle"))
#'   stop("Something went wrong!")  # rollback
#'   exec_db("INSERT INTO logs(message) VALUES (?)", params = list("end"))
#' })
#'
#' set_db_disconn()
#' }
#' @seealso [exec_db()], [query_db()]
#' @export
with_db_transaction <- function(code) {
  has_db_conn()
  con <- get(".MINTDB_CONN", envir = .MINTDB_ENV, inherits = FALSE)

  # pool-aware transaction context
  if (inherits(con, "Pool")) {
    message("Using a pooled connection handle for transaction.")
    handle <- pool::poolCheckout(con)
    on.exit(pool::poolReturn(handle), add = TRUE)
    con <- handle
  }

  DBI::dbBegin(con)
  ok <- FALSE
  on.exit(if (!ok) try(DBI::dbRollback(con), silent = TRUE), add = TRUE)

  result <- force(code)
  DBI::dbCommit(con)
  ok <- TRUE
  invisible(result)
}
