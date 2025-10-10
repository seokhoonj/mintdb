# mintdb

<!-- badges: start -->

[![CRAN status](https://www.r-pkg.org/badges/version/mintdb)](https://CRAN.R-project.org/package=mintdb) [![R-CMD-check](https://github.com/seokhoonj/mintdb/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/seokhoonj/mintdb/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

**mintdb** (Minimal Interface for Networked Transactions & Databases) provides a lightweight and consistent way to connect, query, and manage multiple database backends (MariaDB, MySQL, PostgreSQL, SQLite, ODBC). It supports both direct `DBI` connections and optional connection pooling via the **pool** package.

## Installation

You can install the development version of **mintdb** from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("seokhoonj/mintdb")
```

## Quick start (one-off session)

`set_db_conn_info()` sets environment variables **only for the current R session**.\
Good for quick experiments and temporary scripts.

``` r
library(mintdb)

# Set connection info (example: SQLite)
set_db_conn_info(driver = "sqlite", filepath = "data/test.sqlite")

# Connect
set_db_conn()

# Query data
query_db("SELECT 1 AS result")

# Run non-SELECT command
exec_db("CREATE TABLE demo(id INTEGER, name TEXT)")

# Transaction example
with_db_transaction({
  exec_db("INSERT INTO demo VALUES (?, ?)", params = list(1, "Alice"))
  exec_db("INSERT INTO demo VALUES (?, ?)", params = list(2, "Bob"))
})

# Disconnect
set_db_disconn()
```

## Persistent setup via `.Renviron` (recommended)

For repeated use (Shiny apps, scheduled jobs, shared projects), put your settings in `~/.Renviron` (or a project-local `.Renviron`).\
This way, you can simply call `set_db_conn()` without retyping credentials each time.

1.  Open your `.Renviron`:

``` r
usethis::edit_r_environ()
```

2.  Add entries:

``` ini
# Postgres example:
MINTDB_DRIVER=postgres  
MINTDB_HOST=localhost  
MINTDB_DBNAME=app  
MINTDB_USER=postgres  
MINTDB_PASSWORD=secret  
MINTDB_PORT=5432

# SQLite example:
MINTDB_DRIVER=sqlite  
MINTDB_FILEPATH=data/app.sqlite  
```

3.  Restart R, then:

``` r
library(mintdb)  
set_db_conn()        # uses values from .Renviron  
query_db("SELECT NOW()")  
set_db_disconn()
```

> **Security tip:**\
> Do **not** commit `.Renviron` to version control.\
> Add `^\\.Renviron$` to `.Rbuildignore` and `.Renviron` to `.gitignore`.
