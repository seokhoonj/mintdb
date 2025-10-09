.MINTDB_ENV <- NULL
.onLoad <- function(libname, pkgname) {
  .MINTDB_ENV <<- new.env(parent = emptyenv())
  assign(".MINTDB_CONN", NULL, envir = .MINTDB_ENV)
}

.onUnload <- function(libpath) {
  env <- .MINTDB_ENV
  if (is.environment(env) && exists(".MINTDB_CONN", envir = env, inherits = FALSE)) {
    conn <- get(".MINTDB_CONN", envir = env, inherits = FALSE)
    # Close gracefully whether it's a DBI connection or a pool
    try({
      if (inherits(conn, "Pool")) {
        if (requireNamespace("pool", quietly = TRUE)) pool::poolClose(conn)
      } else if (inherits(conn, "DBIConnection")) {
        if (DBI::dbIsValid(conn)) DBI::dbDisconnect(conn)
      }
    }, silent = TRUE)
    rm(".MINTDB_CONN", envir = env)
  }
}
