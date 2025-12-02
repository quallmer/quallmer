#' Trail compare: run the same task across multiple settings
#'
#' Apply a quallmer task to the same data and text column for a set of
#' settings, returning one \code{trail_record} per setting.
#'
#' @param data A data frame containing the text to be annotated.
#' @param text_col Character scalar. Name of the text column.
#' @param task A quallmer task object.
#' @param settings A named list of \code{trail_setting} objects. The
#'   names will be used as identifiers for each setting (e.g. coder IDs).
#' @param id_col Optional character scalar. Name of the unit identifier
#'   column. If \code{NULL}, a temporary \code{".trail_unit_id"} will be
#'   created and shared across all records.
#' @param cache_dir Optional directory for caching. Passed to
#'   \code{trail_record()}.
#' @param overwrite Logical. If \code{TRUE}, ignore cache for all
#'   settings and recompute.
#' @param annotate_fun Function used to perform the annotation, passed to
#'   \code{trail_record()}.
#'
#' @return An object of class \code{"trail_compare"} containing a named
#'   list of \code{trail_record} objects and some basic metadata.
#' @export
trail_compare <- function(
    data,
    text_col,
    task,
    settings,
    id_col      = NULL,
    cache_dir   = "trail_cache",
    overwrite   = FALSE,
    annotate_fun = annotate
) {
  stopifnot(is.list(settings), length(settings) > 0L)
  if (is.null(names(settings)) || any(!nzchar(names(settings)))) {
    stop("settings must be a named list; names will be used as setting IDs.")
  }
  stopifnot(all(vapply(settings, inherits, logical(1), "trail_setting")))

  # Shared ID column for all records
  if (is.null(id_col)) {
    id_col <- ".trail_unit_id"
    data[[id_col]] <- seq_len(nrow(data))
  } else if (!id_col %in% names(data)) {
    stop("id_col '", id_col, "' not found in data.")
  }

  records <- lapply(settings, function(s) {
    trail_record(
      data         = data,
      text_col     = text_col,
      task         = task,
      setting      = s,
      id_col       = id_col,
      cache_dir    = cache_dir,
      overwrite    = overwrite,
      annotate_fun = annotate_fun
    )
  })

  cmp <- structure(
    list(
      records = records,
      meta    = list(
        timestamp    = Sys.time(),
        n_settings   = length(settings),
        setting_ids  = names(settings),
        id_col       = id_col,
        text_col     = text_col,
        n_rows       = nrow(data),
        task_class   = class(task)
      )
    ),
    class = "trail_compare"
  )

  cmp
}

#' Print method for trail_compare
#'
#' @param x A \code{trail_compare} object.
#' @param ... Ignored.
#' @export
print.trail_compare <- function(x, ...) {
  cat("Trail compare\n")
  cat("  Settings: ", paste(x$meta$setting_ids, collapse = ", "), "\n", sep = "")
  cat("  n rows:   ", x$meta$n_rows, "\n", sep = "")
  invisible(x)
}
