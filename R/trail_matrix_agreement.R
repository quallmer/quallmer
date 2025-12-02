#' Convert Trail records to coder-style wide data
#'
#' Treat each setting/record in a Trail comparison as a separate coder
#' and convert the annotations into a wide data frame suitable for
#' agreement analysis.
#'
#' @param x Either a \code{trail_compare} object or a named list of
#'   \code{trail_record} objects.
#' @param id_col Character scalar. Name of the column that identifies
#'   units (documents, paragraphs, etc.). Must be present in each
#'   record's \code{annotations} data.
#' @param label_col Character scalar. Name of the column in each
#'   record's \code{annotations} data containing the code or label of
#'   interest.
#'
#' @return A data frame with one row per unit and one column per
#'   setting/record. The unit ID column is retained under the name
#'   \code{id_col}.
#' @importFrom dplyr bind_rows
#' @importFrom tidyr pivot_wider
#' @export
trail_matrix <- function(x,
                         id_col   = "id",
                         label_col = "label") {

  records <- NULL
  if (inherits(x, "trail_compare")) {
    records <- x$records
  } else if (is.list(x) && length(x) > 0L &&
             all(vapply(x, inherits, logical(1), "trail_record"))) {
    records <- x
  } else {
    stop("x must be a 'trail_compare' or a list of 'trail_record' objects.")
  }

  if (is.null(names(records)) || any(!nzchar(names(records)))) {
    stop("Records must be named; names are used as setting/coder IDs.")
  }

  df_list <- lapply(names(records), function(name) {
    ann <- records[[name]]$annotations
    if (!id_col %in% names(ann)) {
      stop("id_col '", id_col, "' not found in annotations for record '", name, "'.")
    }
    if (!label_col %in% names(ann)) {
      stop("label_col '", label_col, "' not found in annotations for record '", name, "'.")
    }
    data.frame(
      unit_id = ann[[id_col]],
      coder   = name,
      code    = ann[[label_col]],
      stringsAsFactors = FALSE
    )
  })

  long_all <- dplyr::bind_rows(df_list)

  wide <- tidyr::pivot_wider(
    long_all,
    names_from  = coder,
    values_from = code
  )

  names(wide)[names(wide) == "unit_id"] <- id_col
  wide
}

#' Compute agreement across Trail settings
#'
#' Convenience helper to compute intercoder reliability across multiple
#' Trail records or a Trail comparison by treating each setting as a
#' coder.
#'
#' @param x A \code{trail_compare} object or a list of \code{trail_record}
#'   objects.
#' @param id_col Character scalar. Name of the unit identifier column in
#'   the resulting wide data (defaults to "id").
#' @param label_col Character scalar. Name of the label column in each
#'   record's annotations (defaults to "label").
#' @param min_coders Integer. Minimum number of non-missing coders per
#'   unit required for inclusion. Passed through to \code{agreement_fun}.
#' @param agreement_fun Function used to compute agreement. Defaults to
#'   \code{agreement()}, which is expected to accept \code{data},
#'   \code{unit_id_col}, \code{coder_cols}, and \code{min_coders}.
#'
#' @return The result of calling \code{agreement_fun()} on the wide data,
#'   typically a data frame of agreement statistics.
#' @export
trail_agreement <- function(
    x,
    id_col        = "id",
    label_col     = "label",
    min_coders    = 2L,
    agreement_fun = agreement
) {
  wide <- trail_matrix(x, id_col = id_col, label_col = label_col)
  coder_cols <- setdiff(names(wide), id_col)

  if (length(coder_cols) < 2L) {
    stop("Need at least two setting/coder columns to compute agreement.")
  }

  agreement_fun(
    data        = wide,
    unit_id_col = id_col,
    coder_cols  = coder_cols,
    min_coders  = min_coders
  )
}
