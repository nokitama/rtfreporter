# Internal utility: inches to twips.
.in_to_twips <- function(x) {
  as.integer(round(x * 1440))
}

# Internal utility: merge two named lists.
.merge_list <- function(base, override) {
  if (is.null(override)) {
    return(base)
  }
  out <- base
  for (nm in names(override)) {
    out[[nm]] <- override[[nm]]
  }
  out
}

# Internal utility: validate positive integer-like index.
.assert_index <- function(x, max_value, label) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < 1L || x > max_value) {
    stop(sprintf("%s is out of range.", label), call. = FALSE)
  }
  as.integer(x)
}

#' RTF report object
#'
#' `rtfreport` represents one RTF report and stores content in
#' document -> section -> page hierarchy.
#'
#' @export
rtfreport <- R6::R6Class(
  classname = "rtfreport",
  public = list(
    document = NULL,
    sections = NULL,

    initialize = function(
      font_table = NULL,
      color_table = NULL,
      default_page = NULL,
      default_header = NULL,
      default_footer = NULL,
      default_format = NULL
    ) {
      if (is.null(font_table)) {
        font_table <- list(list(name = "Courier"))
      }
      if (is.null(color_table)) {
        color_table <- c("#000000")
      }
      if (is.null(default_page)) {
        default_page <- list(
          paper = "letter",
          orientation = "landscape",
          width_twips = .in_to_twips(11),
          height_twips = .in_to_twips(8.5),
          margin_top_twips = .in_to_twips(0.75),
          margin_bottom_twips = .in_to_twips(0.75),
          margin_left_twips = .in_to_twips(0.5),
          margin_right_twips = .in_to_twips(0.5)
        )
      }
      if (is.null(default_header)) {
        # Default: empty rows (no document-wide header).
        # Sections provide their own header row via add_section(header=...).
        default_header <- list(rows = list(), width_twips = NULL)
      }
      if (is.null(default_footer)) {
        # Default: empty rows. Section footers added via set_section_footer.
        # top_border = TRUE: draw a horizontal line above footer by default.
        default_footer <- list(rows = list(), width_twips = NULL, top_border = TRUE)
      }
      if (is.null(default_format)) {
        default_format <- list(
          font_index = 0L,
          font_size_half_points = 18L,
          line_spacing = 1L,
          table_cell_height_twips = 240L
        )
      }

      self$document <- list(
        font_table = font_table,
        color_table = color_table,
        default_page = default_page,
        default_header = default_header,
        default_footer = default_footer,
        default_format = default_format
      )
      self$sections <- list()
      invisible(self)
    },

    add_section = function(header = NULL, footer = NULL) {
      section <- list(
        header = header,
        footer = footer,
        pages = list()
      )
      self$sections[[length(self$sections) + 1L]] <- section
      length(self$sections)
    },

    get_section = function(section_index) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]
    },

    set_section_header = function(section_index, header) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$header <- header
      invisible(self)
    },

    set_section_footer = function(section_index, footer) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$footer <- footer
      invisible(self)
    },

    add_page = function(section_index, title = NULL, content = list(), footer_notes = NULL, page_options = NULL) {
      sec_idx <- .assert_index(section_index, length(self$sections), "section_index")

      page <- list(
        title = title,
        content = content,
        footer_notes = footer_notes,
        page_options = page_options
      )
      sec <- self$sections[[sec_idx]]
      sec$pages[[length(sec$pages) + 1L]] <- page
      self$sections[[sec_idx]] <- sec
      length(sec$pages)
    },

    get_page = function(section_index, page_index) {
      sec_idx <- .assert_index(section_index, length(self$sections), "section_index")
      sec <- self$sections[[sec_idx]]
      page_idx <- .assert_index(page_index, length(sec$pages), "page_index")
      sec$pages[[page_idx]]
    },

    set_page_title = function(section_index, page_index, title) {
      sec_idx <- .assert_index(section_index, length(self$sections), "section_index")
      page_idx <- .assert_index(page_index, length(self$sections[[sec_idx]]$pages), "page_index")
      self$sections[[sec_idx]]$pages[[page_idx]]$title <- title
      invisible(self)
    },

    set_page_footer_notes = function(section_index, page_index, footer_notes) {
      sec_idx <- .assert_index(section_index, length(self$sections), "section_index")
      page_idx <- .assert_index(page_index, length(self$sections[[sec_idx]]$pages), "page_index")
      self$sections[[sec_idx]]$pages[[page_idx]]$footer_notes <- footer_notes
      invisible(self)
    },

    set_page_options = function(section_index, page_index, page_options) {
      sec_idx <- .assert_index(section_index, length(self$sections), "section_index")
      page_idx <- .assert_index(page_index, length(self$sections[[sec_idx]]$pages), "page_index")
      self$sections[[sec_idx]]$pages[[page_idx]]$page_options <- page_options
      invisible(self)
    },

    add_block = function(section_index, page_index, block) {
      if (!is.list(block) || is.null(block$type)) {
        stop("`block` must be a list with `type`.", call. = FALSE)
      }
      sec_idx <- .assert_index(section_index, length(self$sections), "section_index")
      page_idx <- .assert_index(page_index, length(self$sections[[sec_idx]]$pages), "page_index")
      page <- self$sections[[sec_idx]]$pages[[page_idx]]
      page$content[[length(page$content) + 1L]] <- block
      self$sections[[sec_idx]]$pages[[page_idx]] <- page
      invisible(self)
    },

    add_table = function(section_index, page_index, data, footer = NULL, metadata = NULL) {
      block <- list(type = "table", data = data, footer = footer, metadata = metadata)
      self$add_block(section_index = section_index, page_index = page_index, block = block)
    },

    add_listing = function(section_index, page_index, data, footer = NULL, metadata = NULL) {
      block <- list(type = "listing", data = data, footer = footer, metadata = metadata)
      self$add_block(section_index = section_index, page_index = page_index, block = block)
    },

    add_figure = function(section_index, page_index, path, footer = NULL, metadata = NULL) {
      if (inherits(path, "rtfplot")) {
        block <- list(type = "figure", data = path, footer = footer, metadata = metadata)
      } else {
        block <- list(type = "figure", path = path, footer = footer, metadata = metadata)
      }
      self$add_block(section_index = section_index, page_index = page_index, block = block)
    },

    set_document_defaults = function(
      font_table = NULL,
      color_table = NULL,
      default_page = NULL,
      default_header = NULL,
      default_footer = NULL,
      default_format = NULL
    ) {
      if (!is.null(font_table)) {
        self$document$font_table <- font_table
      }
      if (!is.null(color_table)) {
        self$document$color_table <- color_table
      }
      if (!is.null(default_page)) {
        self$document$default_page <- .merge_list(self$document$default_page, default_page)
      }
      if (!is.null(default_header)) {
        self$document$default_header <- .merge_list(self$document$default_header, default_header)
      }
      if (!is.null(default_footer)) {
        self$document$default_footer <- .merge_list(self$document$default_footer, default_footer)
      }
      if (!is.null(default_format)) {
        self$document$default_format <- .merge_list(self$document$default_format, default_format)
      }
      invisible(self)
    },

    set_default_header = function(header) {
      self$document$default_header <- .merge_list(self$document$default_header, header)
      invisible(self)
    },

    set_default_footer = function(footer) {
      self$document$default_footer <- .merge_list(self$document$default_footer, footer)
      invisible(self)
    },

    set_default_page = function(page) {
      self$document$default_page <- .merge_list(self$document$default_page, page)
      invisible(self)
    },

    set_default_format = function(fmt) {
      self$document$default_format <- .merge_list(self$document$default_format, fmt)
      invisible(self)
    },

    validate = function() {
      if (length(self$sections) == 0L) {
        stop("rtfreport must contain at least one section.", call. = FALSE)
      }
      for (i in seq_along(self$sections)) {
        sec <- self$sections[[i]]
        if (length(sec$pages) == 0L) {
          stop(sprintf("Section %d must contain at least one page.", i), call. = FALSE)
        }
        for (j in seq_along(sec$pages)) {
          page <- sec$pages[[j]]
          if (!is.list(page$content)) {
            stop(sprintf("Section %d page %d content must be a list.", i, j), call. = FALSE)
          }
          for (k in seq_along(page$content)) {
            block <- page$content[[k]]
            if (is.null(block$type)) {
              stop(sprintf("Section %d page %d block %d must define `type`.", i, j, k), call. = FALSE)
            }
            if (!block$type %in% c("table", "listing", "figure")) {
              stop(sprintf("Unsupported block type `%s`.", block$type), call. = FALSE)
            }
            if (block$type %in% c("table", "listing") && is.null(block$data)) {
              stop(sprintf("Section %d page %d block %d requires `data`.", i, j, k), call. = FALSE)
            }
            if (block$type == "figure" &&
                is.null(block$path) && !inherits(block$data, "rtfplot")) {
              stop(sprintf("Section %d page %d block %d requires `path` or an rtfplot object.", i, j, k), call. = FALSE)
            }
          }
        }
      }
      invisible(TRUE)
    }
  )
)
